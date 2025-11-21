#!/usr/bin/env bash
#
# cluster-snapshot.sh - Get a complete picture of the Kubernetes cluster
#
# This script gathers comprehensive information about the cluster state including:
# - Cluster and node information
# - All workloads (deployments, statefulsets, daemonsets, jobs)
# - Networking (services, ingresses, certificates)
# - Storage (PVCs, storage classes)
# - Helm releases
# - PostgreSQL clusters
# - Resource usage
#
# OPTIMIZED VERSION: GNU Parallel for maximum performance

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color
DIM='\033[2m'

# Create temp directory for parallel execution
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Output separator
separator() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${CYAN}$(printf '─%.0s' {1..80})${NC}"
}

section() {
    echo -e "\n${BOLD}${MAGENTA}▶ $1${NC}"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

# Start snapshot
clear
header "KUBERNETES CLUSTER SNAPSHOT"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"

separator

# ============================================================================
# PHASE 1: Launch all data gathering commands in parallel
# ============================================================================

# Define all commands to run in parallel
cat > "$TMPDIR/commands.txt" << 'EOF'
kubectl version --short 2>/dev/null || kubectl version 2>&1
kubectl cluster-info 2>&1
kubectl config current-context 2>&1
kubectl get nodes -o wide 2>&1
kubectl top nodes 2>&1
kubectl get namespaces 2>&1
kubectl get all -A --no-headers 2>&1
kubectl get ingressroute -A 2>&1
kubectl get svc -A -o wide 2>&1
kubectl get middleware -A 2>&1
kubectl get certificate -A 2>&1
kubectl get certificate -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status,SECRET:.spec.secretName,ISSUER:.spec.issuerRef.name 2>&1
kubectl get pvc -A 2>&1
kubectl get storageclass 2>&1
kubectl get pvc -A -o json 2>&1
kubectl get pods -n storage -l app.kubernetes.io/name=redis 2>&1
kubectl get svc -n storage -l app.kubernetes.io/name=redis 2>&1
kubectl get all -n auth 2>&1
kubectl get all -n zitadel 2>&1
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus 2>&1
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana 2>&1
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki 2>&1
kubectl top pods -A --sort-by=memory 2>&1
kubectl top pods -A --no-headers 2>&1
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>&1
kubectl get pods -A -o json 2>&1
kubectl get events -A --sort-by='.lastTimestamp' 2>&1
kubectl get ingressroute -A -o json 2>&1
kubectl get deployments -A -o json 2>&1
kubectl get statefulsets -A -o json 2>&1
kubectl get nodes --no-headers 2>&1
kubectl get namespaces --no-headers 2>&1
kubectl get deployments -A --no-headers 2>&1
kubectl get statefulsets -A --no-headers 2>&1
kubectl get daemonsets -A --no-headers 2>&1
kubectl get services -A --no-headers 2>&1
kubectl get pods -A --no-headers 2>&1
EOF

# Add Talos command if available
if command -v talosctl &> /dev/null && [ -f "$HOME/.talos/config" ] 2>/dev/null; then
    echo "talosctl version --nodes talos.pane.run 2>&1" >> "$TMPDIR/commands.txt"
fi

# Add Helm command if available
if command -v helm &> /dev/null; then
    echo "helm list -A 2>&1" >> "$TMPDIR/commands.txt"
fi

# Add PostgreSQL commands if CRD exists
if kubectl get crd clusters.postgresql.cnpg.io &> /dev/null; then
    echo "kubectl get cluster -A 2>&1" >> "$TMPDIR/commands.txt"
    echo "kubectl get svc -n postgres 2>&1" >> "$TMPDIR/commands.txt"
fi

# Output filenames matching command order
cat > "$TMPDIR/filenames.txt" << 'EOF'
k8s_version
cluster_info
current_context
nodes
node_resources
namespaces
all_resources
ingressroutes
services
middlewares
certificates
certificate_status
pvcs
storageclasses
pvcs_json
redis_pods
redis_services
auth_all
zitadel_all
prometheus_pods
grafana_pods
loki_pods
pod_resources
pod_resources_raw
unhealthy_pods
pods_json
events
ingressroutes_json
deployments_json
statefulsets_json
nodes_count
namespaces_count
deployments_count
statefulsets_count
daemonsets_count
services_count
pods_count
EOF

# Add optional filenames
[ -f "$HOME/.talos/config" ] 2>/dev/null && echo "talos_version" >> "$TMPDIR/filenames.txt"
command -v helm &> /dev/null && echo "helm_releases" >> "$TMPDIR/filenames.txt"
kubectl get crd clusters.postgresql.cnpg.io &> /dev/null && echo -e "pg_clusters\npg_services" >> "$TMPDIR/filenames.txt"

# Run commands in background jobs
i=0
while IFS= read -r cmd && IFS= read -r filename <&3; do
    (eval "$cmd" > "$TMPDIR/$filename" 2>&1) &
    i=$((i + 1))
done < "$TMPDIR/commands.txt" 3< "$TMPDIR/filenames.txt"

# Gather namespace-specific workloads in parallel
namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -vE '^(kube-|default)')

for ns in $namespaces; do
    (kubectl get all -n "$ns" 2>/dev/null > "$TMPDIR/ns_${ns}" || true) &
done

# Wait for all background jobs to complete (no progress indicator)
wait

separator

# ============================================================================
# PHASE 2: Display results from gathered data
# ============================================================================

# ============================================================================
section "CLUSTER INFORMATION"
# ============================================================================

echo -e "${BOLD}Kubernetes Version:${NC}"
cat "$TMPDIR/k8s_version"

echo -e "\n${BOLD}Cluster Info:${NC}"
cat "$TMPDIR/cluster_info"

echo -e "\n${BOLD}Current Context:${NC}"
cat "$TMPDIR/current_context"

if [ -f "$TMPDIR/talos_version" ]; then
    echo -e "\n${BOLD}Talos Version:${NC}"
    cat "$TMPDIR/talos_version" || echo "Talos not accessible"
fi

separator

# ============================================================================
section "NODE INFORMATION"
# ============================================================================

echo -e "${BOLD}Nodes:${NC}"
cat "$TMPDIR/nodes"

echo -e "\n${BOLD}Node Resources:${NC}"
if grep -q "error" "$TMPDIR/node_resources" 2>/dev/null; then
    echo "metrics-server not available or no metrics yet"
else
    cat "$TMPDIR/node_resources"
fi

separator

# ============================================================================
section "NAMESPACES"
# ============================================================================

echo -e "${BOLD}All Namespaces:${NC}"
cat "$TMPDIR/namespaces"

echo -e "\n${BOLD}Namespace Summary:${NC}"
cat "$TMPDIR/all_resources" | awk '{print $1}' | sort | uniq -c | sort -rn

separator

# ============================================================================
section "WORKLOADS BY NAMESPACE"
# ============================================================================

for ns_file in "$TMPDIR"/ns_*; do
    [ -f "$ns_file" ] || continue
    ns=$(basename "$ns_file" | sed 's/^ns_//')

    if [ -s "$ns_file" ] && [ "$(wc -l < "$ns_file")" -gt 0 ]; then
        echo -e "\n${BOLD}${GREEN}Namespace: $ns${NC}"
        cat "$ns_file"
    fi
done

separator

# ============================================================================
section "HELM RELEASES"
# ============================================================================

if [ -f "$TMPDIR/helm_releases" ]; then
    echo -e "${BOLD}Installed Helm Charts:${NC}"
    cat "$TMPDIR/helm_releases"
else
    echo "Helm not installed"
fi

separator

# ============================================================================
section "INGRESS & ROUTING"
# ============================================================================

echo -e "${BOLD}IngressRoutes (Traefik):${NC}"
cat "$TMPDIR/ingressroutes"

echo -e "\n${BOLD}Services with External Access:${NC}"
cat "$TMPDIR/services" | grep -E 'LoadBalancer|NodePort|externalIPs|EXTERNAL-IP' | head -20 || echo "No external services"

separator

# ============================================================================
section "TLS CERTIFICATES"
# ============================================================================

echo -e "${BOLD}Certificates (cert-manager):${NC}"
cat "$TMPDIR/certificates"

echo -e "\n${BOLD}Certificate Status:${NC}"
cat "$TMPDIR/certificate_status"

separator

# ============================================================================
section "STORAGE"
# ============================================================================

echo -e "${BOLD}Persistent Volume Claims:${NC}"
cat "$TMPDIR/pvcs"

echo -e "\n${BOLD}Storage Classes:${NC}"
cat "$TMPDIR/storageclasses"

echo -e "\n${BOLD}Storage Summary by Namespace:${NC}"
if command -v jq &> /dev/null; then
    cat "$TMPDIR/pvcs_json" | jq -r '.items[] | "\(.metadata.namespace)\t\(.spec.resources.requests.storage)"' | \
        awk '{ns[$1]+=$2} END {for (n in ns) printf "%-30s %s\n", n, ns[n]}' | sort -k2 -hr 2>/dev/null || \
        kubectl get pvc -A -o custom-columns=NAMESPACE:.metadata.namespace,SIZE:.spec.resources.requests.storage
else
    kubectl get pvc -A -o custom-columns=NAMESPACE:.metadata.namespace,SIZE:.spec.resources.requests.storage
fi

separator

# ============================================================================
section "POSTGRESQL CLUSTERS (CloudNative-PG)"
# ============================================================================

if [ -f "$TMPDIR/pg_clusters" ]; then
    echo -e "${BOLD}PostgreSQL Clusters:${NC}"
    cat "$TMPDIR/pg_clusters"

    echo -e "\n${BOLD}PostgreSQL Services:${NC}"
    cat "$TMPDIR/pg_services"
else
    echo "CloudNative-PG not installed"
fi

separator

# ============================================================================
section "REDIS INSTANCES"
# ============================================================================

echo -e "${BOLD}Redis Pods:${NC}"
if [ -s "$TMPDIR/redis_pods" ]; then
    cat "$TMPDIR/redis_pods"
else
    echo "No Redis instances found"
fi

echo -e "\n${BOLD}Redis Services:${NC}"
if [ -s "$TMPDIR/redis_services" ]; then
    cat "$TMPDIR/redis_services"
else
    echo "No Redis services found"
fi

separator

# ============================================================================
section "AUTHENTICATION STACK"
# ============================================================================

echo -e "${BOLD}OAuth2-Proxy:${NC}"
if [ -s "$TMPDIR/auth_all" ]; then
    cat "$TMPDIR/auth_all"
else
    echo "No auth namespace found"
fi

echo -e "\n${BOLD}Zitadel:${NC}"
if [ -s "$TMPDIR/zitadel_all" ]; then
    cat "$TMPDIR/zitadel_all"
else
    echo "No zitadel namespace found"
fi

echo -e "\n${BOLD}Traefik Middlewares:${NC}"
cat "$TMPDIR/middlewares"

separator

# ============================================================================
section "MONITORING STACK"
# ============================================================================

echo -e "${BOLD}Prometheus:${NC}"
if [ -s "$TMPDIR/prometheus_pods" ]; then
    cat "$TMPDIR/prometheus_pods"
else
    echo "No Prometheus found"
fi

echo -e "\n${BOLD}Grafana:${NC}"
if [ -s "$TMPDIR/grafana_pods" ]; then
    cat "$TMPDIR/grafana_pods"
else
    echo "No Grafana found"
fi

echo -e "\n${BOLD}Loki:${NC}"
if [ -s "$TMPDIR/loki_pods" ]; then
    cat "$TMPDIR/loki_pods"
else
    echo "No Loki found"
fi

separator

# ============================================================================
section "RESOURCE USAGE"
# ============================================================================

echo -e "${BOLD}Pod Resource Usage (Top 20):${NC}"
if grep -q "error" "$TMPDIR/pod_resources" 2>/dev/null; then
    echo "metrics-server not available"
else
    head -21 "$TMPDIR/pod_resources"
fi

echo -e "\n${BOLD}CPU Usage by Namespace:${NC}"
if [ -s "$TMPDIR/pod_resources_raw" ] && ! grep -q "error" "$TMPDIR/pod_resources_raw" 2>/dev/null; then
    awk '{ns[$1]+=$2} END {for (n in ns) printf "%-30s %s\n", n, ns[n]}' "$TMPDIR/pod_resources_raw" | \
        sort -k2 -hr | head -10
else
    echo "metrics-server not available"
fi

separator

# ============================================================================
section "POD HEALTH STATUS"
# ============================================================================

echo -e "${BOLD}Pods NOT in Running state:${NC}"
if [ -s "$TMPDIR/unhealthy_pods" ] && [ "$(wc -l < "$TMPDIR/unhealthy_pods")" -gt 1 ]; then
    cat "$TMPDIR/unhealthy_pods"
else
    echo "All pods healthy"
fi

echo -e "\n${BOLD}Pods with Restarts:${NC}"
if command -v jq &> /dev/null && [ -s "$TMPDIR/pods_json" ]; then
    jq -r '.items[] | select(.status.containerStatuses[]?.restartCount > 0) |
        "\(.metadata.namespace)\t\(.metadata.name)\tRestarts: \(.status.containerStatuses[0].restartCount)"' "$TMPDIR/pods_json" 2>/dev/null || \
        echo "No pods with restarts"
else
    echo "No pods with restarts"
fi

separator

# ============================================================================
section "RECENT EVENTS"
# ============================================================================

echo -e "${BOLD}Recent Cluster Events (Last 10):${NC}"
tail -11 "$TMPDIR/events"

separator

# ============================================================================
section "APPLICATION URLS"
# ============================================================================

echo -e "${BOLD}External Access Points:${NC}"
if command -v jq &> /dev/null && [ -s "$TMPDIR/ingressroutes_json" ]; then
    if command -v column &> /dev/null; then
        jq -r '.items[] |
            "\(.spec.routes[0].match | capture("Host\\(`(?<host>[^`]+)`").host)\t\(.metadata.namespace)\t\(.metadata.name)"' "$TMPDIR/ingressroutes_json" 2>/dev/null | \
            column -t -s $'\t' 2>/dev/null || cat "$TMPDIR/ingressroutes"
    else
        jq -r '.items[] |
            "\(.spec.routes[0].match | capture("Host\\(`(?<host>[^`]+)`").host)  \(.metadata.namespace)  \(.metadata.name)"' "$TMPDIR/ingressroutes_json" 2>/dev/null || cat "$TMPDIR/ingressroutes"
    fi
else
    cat "$TMPDIR/ingressroutes"
fi

separator

# ============================================================================
section "LEGACY/INACTIVE COMPONENTS"
# ============================================================================

echo -e "${BOLD}Scaled to Zero:${NC}"
if command -v jq &> /dev/null; then
    if command -v column &> /dev/null; then
        jq -r '.items[] | select(.spec.replicas == 0) |
            "\(.metadata.namespace)\t\(.metadata.name)\tReplicas: 0"' "$TMPDIR/deployments_json" 2>/dev/null | column -t -s $'\t' 2>/dev/null || echo "None"

        jq -r '.items[] | select(.spec.replicas == 0) |
            "\(.metadata.namespace)\t\(.metadata.name)\tReplicas: 0"' "$TMPDIR/statefulsets_json" 2>/dev/null | column -t -s $'\t' 2>/dev/null || echo ""
    else
        jq -r '.items[] | select(.spec.replicas == 0) |
            "\(.metadata.namespace)  \(.metadata.name)  Replicas: 0"' "$TMPDIR/deployments_json" 2>/dev/null || echo "None"

        jq -r '.items[] | select(.spec.replicas == 0) |
            "\(.metadata.namespace)  \(.metadata.name)  Replicas: 0"' "$TMPDIR/statefulsets_json" 2>/dev/null || echo ""
    fi
else
    echo "jq not available for detailed analysis"
fi

echo -e "\n${BOLD}Empty Namespaces:${NC}"
for ns_file in "$TMPDIR"/ns_*; do
    [ -f "$ns_file" ] || continue
    ns=$(basename "$ns_file" | sed 's/^ns_//')

    if [ ! -s "$ns_file" ] || [ "$(wc -l < "$ns_file")" -eq 0 ]; then
        echo "  - $ns (empty)"
    fi
done

separator

# ============================================================================
section "SUMMARY"
# ============================================================================

echo -e "${BOLD}Cluster Statistics:${NC}"
echo "  Nodes:                $(wc -l < "$TMPDIR/nodes_count")"
echo "  Namespaces:           $(wc -l < "$TMPDIR/namespaces_count")"
echo "  Deployments:          $(wc -l < "$TMPDIR/deployments_count")"
echo "  StatefulSets:         $(wc -l < "$TMPDIR/statefulsets_count")"
echo "  DaemonSets:           $(wc -l < "$TMPDIR/daemonsets_count")"
echo "  Services:             $(wc -l < "$TMPDIR/services_count")"
echo "  IngressRoutes:        $(grep -c "ingressroute" "$TMPDIR/ingressroutes" 2>/dev/null || echo 0)"
echo "  Certificates:         $(tail -n +2 "$TMPDIR/certificates" 2>/dev/null | wc -l)"
echo "  PVCs:                 $(tail -n +2 "$TMPDIR/pvcs" 2>/dev/null | wc -l)"
if [ -f "$TMPDIR/helm_releases" ]; then
    echo "  Helm Releases:        $(tail -n +2 "$TMPDIR/helm_releases" 2>/dev/null | wc -l)"
fi

echo -e "\n${BOLD}Total Pods:${NC}"
awk '{print $4}' "$TMPDIR/pods_count" | sort | uniq -c

separator

echo -e "${GREEN}${BOLD}✓ Snapshot complete!${NC}"
echo -e "Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
