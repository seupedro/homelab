#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
REPLICAS=2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$PROJECT_ROOT/k8s/templates"
APPS_DIR="$PROJECT_ROOT/k8s/apps"

# Function to print colored output
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to show usage
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Deploy a web application to Kubernetes with automated health checks and rollback.

Required Options:
  -n, --name NAME           Application name (used for namespace and resource names)
  -s, --subdomain SUBDOMAIN Subdomain for the application (will be SUBDOMAIN.pane.run)
  -i, --image IMAGE         Container image to deploy (e.g., nginx:latest)
  -p, --port PORT           Container port to expose

Optional Options:
  -r, --replicas REPLICAS   Number of replicas (default: 2)
  -h, --help                Show this help message

Examples:
  $0 --name myapp --subdomain myapp --image nginx:latest --port 80
  $0 -n api -s api --image myregistry/api:v1.0 -p 8080 -r 3

EOF
  exit 1
}

# Parse command-line arguments
APP_NAME=""
SUBDOMAIN=""
CONTAINER_IMAGE=""
CONTAINER_PORT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--name)
      APP_NAME="$2"
      shift 2
      ;;
    -s|--subdomain)
      SUBDOMAIN="$2"
      shift 2
      ;;
    -i|--image)
      CONTAINER_IMAGE="$2"
      shift 2
      ;;
    -p|--port)
      CONTAINER_PORT="$2"
      shift 2
      ;;
    -r|--replicas)
      REPLICAS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      print_error "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate required parameters
if [[ -z "$APP_NAME" ]] || [[ -z "$SUBDOMAIN" ]] || [[ -z "$CONTAINER_IMAGE" ]] || [[ -z "$CONTAINER_PORT" ]]; then
  print_error "Missing required parameters"
  usage
fi

# Validate app name (must be valid DNS label)
if ! [[ "$APP_NAME" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
  print_error "Invalid app name. Must be lowercase alphanumeric with hyphens (DNS label format)"
  exit 1
fi

# Validate subdomain
if ! [[ "$SUBDOMAIN" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
  print_error "Invalid subdomain. Must be lowercase alphanumeric with hyphens"
  exit 1
fi

# Validate port is a number
if ! [[ "$CONTAINER_PORT" =~ ^[0-9]+$ ]]; then
  print_error "Invalid port. Must be a number"
  exit 1
fi

# Validate replicas is a number
if ! [[ "$REPLICAS" =~ ^[0-9]+$ ]]; then
  print_error "Invalid replicas. Must be a number"
  exit 1
fi

print_info "Starting deployment for $APP_NAME"
print_info "Configuration:"
echo "  App Name: $APP_NAME"
echo "  Subdomain: $SUBDOMAIN.pane.run"
echo "  Image: $CONTAINER_IMAGE"
echo "  Port: $CONTAINER_PORT"
echo "  Replicas: $REPLICAS"

# Create app directory
APP_DIR="$APPS_DIR/$APP_NAME"
mkdir -p "$APP_DIR"

# Function to process template
process_template() {
  local template_file="$1"
  local output_file="$2"

  sed -e "s|{{APP_NAME}}|$APP_NAME|g" \
      -e "s|{{SUBDOMAIN}}|$SUBDOMAIN|g" \
      -e "s|{{CONTAINER_IMAGE}}|$CONTAINER_IMAGE|g" \
      -e "s|{{CONTAINER_PORT}}|$CONTAINER_PORT|g" \
      -e "s|{{REPLICAS}}|$REPLICAS|g" \
      "$template_file" > "$output_file"
}

print_info "Generating Kubernetes manifests..."

# Generate all manifests from templates
process_template "$TEMPLATE_DIR/namespace.yaml" "$APP_DIR/namespace.yaml"
process_template "$TEMPLATE_DIR/deployment.yaml" "$APP_DIR/deployment.yaml"
process_template "$TEMPLATE_DIR/service.yaml" "$APP_DIR/service.yaml"
process_template "$TEMPLATE_DIR/certificate.yaml" "$APP_DIR/certificate.yaml"
process_template "$TEMPLATE_DIR/ingressroute.yaml" "$APP_DIR/ingressroute.yaml"

print_info "Manifests generated in $APP_DIR"

# Check if namespace exists and deployment exists (for rollback capability)
NAMESPACE_EXISTS=false
DEPLOYMENT_EXISTS=false
PREVIOUS_REVISION=""

if kubectl get namespace "$APP_NAME" &>/dev/null; then
  NAMESPACE_EXISTS=true
  print_info "Namespace $APP_NAME already exists"

  if kubectl get deployment "$APP_NAME" -n "$APP_NAME" &>/dev/null; then
    DEPLOYMENT_EXISTS=true
    # Get current revision for potential rollback
    PREVIOUS_REVISION=$(kubectl rollout history deployment/"$APP_NAME" -n "$APP_NAME" --revision=0 | tail -n 1 | awk '{print $1}')
    print_info "Existing deployment found. Current revision: $PREVIOUS_REVISION"
  fi
else
  print_info "Creating new namespace: $APP_NAME"
fi

# Apply manifests
print_info "Applying Kubernetes manifests..."

kubectl apply -f "$APP_DIR/namespace.yaml"
kubectl apply -f "$APP_DIR/deployment.yaml"
kubectl apply -f "$APP_DIR/service.yaml"
kubectl apply -f "$APP_DIR/certificate.yaml"
kubectl apply -f "$APP_DIR/ingressroute.yaml"

# Wait for rollout
print_info "Waiting for deployment rollout..."
if kubectl rollout status deployment/"$APP_NAME" -n "$APP_NAME" --timeout=5m; then
  print_info "Deployment rollout completed successfully"
else
  print_error "Deployment rollout failed"
  exit 1
fi

# Wait a bit for service to be ready
print_info "Waiting for service to be ready..."
sleep 10

# Run health check
print_info "Running health checks..."
HEALTH_CHECK_SCRIPT="$SCRIPT_DIR/health-check.sh"

if [[ ! -f "$HEALTH_CHECK_SCRIPT" ]]; then
  print_error "Health check script not found at $HEALTH_CHECK_SCRIPT"
  exit 1
fi

if bash "$HEALTH_CHECK_SCRIPT" -u "https://$SUBDOMAIN.pane.run" -r 10 -i 15; then
  print_info "Health checks passed!"
  print_info ""
  print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  print_info "✓ Deployment successful!"
  print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  print_info ""
  print_info "Application URL: https://$SUBDOMAIN.pane.run"
  print_info "Namespace: $APP_NAME"
  print_info "Replicas: $REPLICAS"
  print_info ""
  print_info "Useful commands:"
  echo "  View pods:    kubectl get pods -n $APP_NAME"
  echo "  View logs:    kubectl logs -n $APP_NAME -l app=$APP_NAME --tail=100 -f"
  echo "  Delete app:   kubectl delete namespace $APP_NAME"
  print_info ""
else
  print_error "Health checks failed!"

  if [[ "$DEPLOYMENT_EXISTS" == "true" ]] && [[ -n "$PREVIOUS_REVISION" ]]; then
    print_warn "Attempting automatic rollback to revision $PREVIOUS_REVISION..."

    if kubectl rollout undo deployment/"$APP_NAME" -n "$APP_NAME" --to-revision="$PREVIOUS_REVISION"; then
      print_info "Rollback initiated. Waiting for rollout..."

      if kubectl rollout status deployment/"$APP_NAME" -n "$APP_NAME" --timeout=3m; then
        print_info "Rollback completed successfully"
        print_error "Deployment failed and was rolled back to previous version"
        exit 1
      else
        print_error "Rollback failed!"
        exit 1
      fi
    else
      print_error "Rollback command failed!"
      exit 1
    fi
  else
    print_warn "No previous deployment to rollback to. Manual intervention required."
    print_warn "To delete failed deployment: kubectl delete namespace $APP_NAME"
    exit 1
  fi
fi
