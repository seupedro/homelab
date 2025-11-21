#!/bin/bash
# Script to test the complete authentication flow

set -e

echo "=== Authentication Flow Test ==="
echo ""

# Test Zitadel
echo "1. Testing Zitadel..."
ZITADEL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://zitadel.pane.run/debug/healthz)
if [ "$ZITADEL_STATUS" == "200" ]; then
  echo "   ✓ Zitadel is healthy (HTTP $ZITADEL_STATUS)"
else
  echo "   ❌ Zitadel is not responding correctly (HTTP $ZITADEL_STATUS)"
  exit 1
fi

# Test OAuth2-Proxy
echo "2. Testing OAuth2-Proxy..."
OAUTH2_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://auth.pane.run/ping 2>/dev/null)
if [ "$OAUTH2_STATUS" == "200" ]; then
  echo "   ✓ OAuth2-Proxy is healthy (HTTP $OAUTH2_STATUS)"
else
  echo "   ❌ OAuth2-Proxy is not responding correctly (HTTP $OAUTH2_STATUS)"
  echo "   Note: This may fail if the certificate is not yet issued or OAuth2-Proxy is not deployed"
  exit 1
fi

# Test whoami (unauthenticated)
echo "3. Testing whoami endpoint (unauthenticated)..."
WHOAMI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L https://whoami.pane.run 2>/dev/null)
if [ "$WHOAMI_STATUS" == "302" ] || [ "$WHOAMI_STATUS" == "401" ]; then
  echo "   ✓ whoami is protected (HTTP $WHOAMI_STATUS - redirect to auth)"
elif [ "$WHOAMI_STATUS" == "200" ]; then
  echo "   ⚠ whoami is NOT protected (HTTP $WHOAMI_STATUS - authentication not enabled yet)"
else
  echo "   ❌ Unexpected response from whoami (HTTP $WHOAMI_STATUS)"
fi

# Check Kubernetes resources
echo ""
echo "4. Checking Kubernetes resources..."

echo -n "   Zitadel pods: "
ZITADEL_PODS=$(kubectl get pods -n zitadel -l app.kubernetes.io/name=zitadel --no-headers 2>/dev/null | wc -l)
echo "$ZITADEL_PODS running"

echo -n "   OAuth2-Proxy pods: "
OAUTH2_PODS=$(kubectl get pods -n auth -l app.kubernetes.io/name=oauth2-proxy --no-headers 2>/dev/null | wc -l)
if [ "$OAUTH2_PODS" -gt 0 ]; then
  echo "$OAUTH2_PODS running"
else
  echo "0 (not deployed yet)"
fi

echo -n "   Middleware: "
MIDDLEWARE=$(kubectl get middleware -n auth oauth2-forward-auth --no-headers 2>/dev/null | wc -l)
if [ "$MIDDLEWARE" -gt 0 ]; then
  echo "✓ configured"
else
  echo "❌ not configured"
fi

echo -n "   Certificates: "
CERTS_READY=$(kubectl get certificate -n zitadel,auth -o jsonpath='{.items[?(@.status.conditions[0].status=="True")].metadata.name}' 2>/dev/null | wc -w)
CERTS_TOTAL=$(kubectl get certificate -n zitadel,auth --no-headers 2>/dev/null | wc -l)
echo "$CERTS_READY/$CERTS_TOTAL ready"

echo ""
echo "=== Test Complete ==="
echo ""
echo "Access URLs:"
echo "  - Zitadel:       https://zitadel.pane.run"
echo "  - OAuth2-Proxy:  https://auth.pane.run/ping"
echo "  - Whoami:        https://whoami.pane.run"
