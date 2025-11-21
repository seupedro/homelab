#!/bin/bash
# Script to deploy OAuth2-Proxy after OAuth2 application is created in Zitadel

set -e

echo "=== OAuth2-Proxy Deployment Script ==="
echo ""

# Check if secrets have been updated
if grep -q "PLACEHOLDER" k8s/auth/secrets.yaml; then
  echo "❌ ERROR: Please update k8s/auth/secrets.yaml with actual Client ID and Client Secret first!"
  echo ""
  echo "Steps:"
  echo "1. Create OAuth2 application in Zitadel (https://zitadel.pane.run)"
  echo "2. Edit k8s/auth/secrets.yaml and replace PLACEHOLDER values"
  echo "3. Run this script again"
  echo ""
  echo "See k8s/auth/SETUP.md for detailed instructions"
  exit 1
fi

echo "✓ Secrets file appears to be configured"
echo ""

# Apply secrets
echo "1. Applying secrets..."
kubectl apply -f k8s/auth/secrets.yaml
echo "   ✓ Secrets applied"
echo ""

# Add Helm repo
echo "2. Adding OAuth2-Proxy Helm repository..."
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests >/dev/null 2>&1 || true
helm repo update >/dev/null
echo "   ✓ Helm repo updated"
echo ""

# Install OAuth2-Proxy
echo "3. Installing OAuth2-Proxy..."
if helm status oauth2-proxy -n auth >/dev/null 2>&1; then
  echo "   OAuth2-Proxy already installed, upgrading..."
  helm upgrade oauth2-proxy oauth2-proxy/oauth2-proxy -n auth -f k8s/auth/values.yaml
else
  helm install oauth2-proxy oauth2-proxy/oauth2-proxy -n auth -f k8s/auth/values.yaml
fi
echo "   ✓ OAuth2-Proxy deployed"
echo ""

# Apply certificate and IngressRoute
echo "4. Applying certificate and IngressRoute..."
kubectl apply -f k8s/auth/certificate.yaml
kubectl apply -f k8s/auth/ingressroute.yaml
echo "   ✓ Certificate and IngressRoute applied"
echo ""

# Apply middleware
echo "5. Applying ForwardAuth middleware..."
kubectl apply -f k8s/auth/middleware-forwardauth.yaml
echo "   ✓ Middleware applied"
echo ""

# Wait for pods to be ready
echo "6. Waiting for OAuth2-Proxy to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=oauth2-proxy -n auth --timeout=120s
echo "   ✓ OAuth2-Proxy is ready"
echo ""

# Wait for certificate
echo "7. Waiting for TLS certificate to be issued..."
kubectl wait --for=condition=ready certificate/auth-tls -n auth --timeout=120s 2>/dev/null || echo "   ⚠ Certificate still pending (this may take a few minutes)"
echo ""

# Test endpoints
echo "8. Testing endpoints..."
echo -n "   Zitadel health: "
curl -s -o /dev/null -w "%{http_code}" https://zitadel.pane.run/debug/healthz
echo ""

echo -n "   OAuth2-Proxy health: "
curl -s -o /dev/null -w "%{http_code}" https://auth.pane.run/ping 2>/dev/null || echo "pending (certificate may not be ready yet)"
echo ""

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "1. Update whoami IngressRoute to add authentication middleware"
echo "2. Test the authentication flow at https://whoami.pane.run"
echo ""
echo "See k8s/auth/SETUP.md for detailed instructions"
