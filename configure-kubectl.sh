#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get server IP from terraform output
echo -e "${YELLOW}Getting server IP from OpenTofu...${NC}"
SERVER_IP=$(tofu output -raw ipv4_address 2>/dev/null || echo "")

if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Error: Could not get server IP from OpenTofu output${NC}"
    echo "Please run 'tofu apply' first or provide the IP manually"
    exit 1
fi

echo -e "${GREEN}Server IP: $SERVER_IP${NC}"

# Configuration
REMOTE_USER="root"
KUBECONFIG_PATH="$HOME/.kube/config"
CONTEXT_NAME="pane-homelab-k8s"
MAX_RETRIES=30
RETRY_INTERVAL=10

echo -e "${YELLOW}Waiting for k3s to be ready on the server...${NC}"
echo "This may take a few minutes as cloud-init completes the installation"

# Function to check if k3s is ready
check_k3s_ready() {
    ssh -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -q ${REMOTE_USER}@${SERVER_IP} \
        "systemctl is-active --quiet k3s && test -f /etc/rancher/k3s/k3s.yaml" 2>/dev/null
}

# Wait for k3s to be ready
RETRY_COUNT=0
while ! check_k3s_ready; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${RED}Timeout: k3s did not become ready after $((MAX_RETRIES * RETRY_INTERVAL)) seconds${NC}"
        echo "You can check the status manually with: ssh ${REMOTE_USER}@${SERVER_IP} 'systemctl status k3s'"
        exit 1
    fi
    echo -e "${YELLOW}Attempt $RETRY_COUNT/$MAX_RETRIES: k3s not ready yet, waiting ${RETRY_INTERVAL}s...${NC}"
    sleep $RETRY_INTERVAL
done

echo -e "${GREEN}k3s is ready!${NC}"

# Create .kube directory if it doesn't exist
mkdir -p "$HOME/.kube"

# Backup existing kubeconfig if it exists
if [ -f "$KUBECONFIG_PATH" ]; then
    BACKUP_PATH="${KUBECONFIG_PATH}.backup.$(date +%Y%m%d-%H%M%S)"
    echo -e "${YELLOW}Backing up existing kubeconfig to: $BACKUP_PATH${NC}"
    cp "$KUBECONFIG_PATH" "$BACKUP_PATH"
fi

# Retrieve kubeconfig from remote server
echo -e "${YELLOW}Retrieving kubeconfig from remote server...${NC}"
TEMP_KUBECONFIG=$(mktemp)

ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -q ${REMOTE_USER}@${SERVER_IP} \
    "cat /etc/rancher/k3s/k3s.yaml" > "$TEMP_KUBECONFIG"

# Replace localhost with server IP and update context name
sed -i.bak \
    -e "s/127.0.0.1/${SERVER_IP}/g" \
    -e "s/: default/: ${CONTEXT_NAME}/g" \
    -e "s/name: default$/name: ${CONTEXT_NAME}/g" \
    "$TEMP_KUBECONFIG"

# Merge with existing kubeconfig or create new one
if [ -f "$KUBECONFIG_PATH" ] && [ -s "$KUBECONFIG_PATH" ]; then
    echo -e "${YELLOW}Merging with existing kubeconfig...${NC}"

    # Use kubectl to merge configs
    KUBECONFIG="${KUBECONFIG_PATH}:${TEMP_KUBECONFIG}" kubectl config view --flatten > "${TEMP_KUBECONFIG}.merged"
    mv "${TEMP_KUBECONFIG}.merged" "$KUBECONFIG_PATH"
else
    echo -e "${YELLOW}Creating new kubeconfig...${NC}"
    mv "$TEMP_KUBECONFIG" "$KUBECONFIG_PATH"
fi

# Set permissions
chmod 600 "$KUBECONFIG_PATH"

# Clean up temp files
rm -f "$TEMP_KUBECONFIG" "${TEMP_KUBECONFIG}.bak"

# Switch to the new context
echo -e "${YELLOW}Switching to context: ${CONTEXT_NAME}${NC}"
kubectl config use-context "$CONTEXT_NAME"

# Test the connection
echo -e "${YELLOW}Testing connection to cluster...${NC}"
if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓ Successfully configured kubectl!${NC}"
    echo ""
    echo "Cluster information:"
    kubectl cluster-info
    echo ""
    echo "Nodes:"
    kubectl get nodes
    echo ""
    echo -e "${GREEN}You can now use kubectl to manage your cluster${NC}"
    echo "Context name: ${CONTEXT_NAME}"
else
    echo -e "${RED}Warning: kubectl configuration completed but connection test failed${NC}"
    echo "You may need to check firewall rules or wait a bit longer for k3s to fully start"
    exit 1
fi
