#!/bin/bash
# Script to create OAuth2 application in Zitadel via API

set -e

echo "=== Creating OAuth2 Application in Zitadel ==="

# Get the service account key from Kubernetes secret
echo "1. Retrieving Zitadel service account key..."
SA_KEY=$(kubectl -n zitadel get secret iam-admin -o jsonpath='{.data.iam-admin\.json}' | base64 -d)

# Extract client ID and key ID from the service account key
CLIENT_ID=$(echo "$SA_KEY" | jq -r '.clientId')
KEY_ID=$(echo "$SA_KEY" | jq -r '.keyId')
USER_ID=$(echo "$SA_KEY" | jq -r '.userId')

echo "   Service Account User ID: $USER_ID"
echo "   Client ID: $CLIENT_ID"

# Save the service account key to a temporary file
echo "$SA_KEY" > /tmp/zitadel-sa-key.json

# Get JWT token for authentication
echo ""
echo "2. Authenticating with Zitadel..."
TOKEN_RESPONSE=$(curl -s -X POST https://zitadel.pane.run/oauth/v2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
  -d "scope=openid profile email urn:zitadel:iam:org:project:id:zitadel:aud" \
  -d "assertion=$(echo "$SA_KEY" | jq -r '.key')")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "   ERROR: Failed to get access token"
  echo "   Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "   ✓ Successfully authenticated"

# Create a project for the OAuth2 application
echo ""
echo "3. Creating project 'Authentication Proxy'..."
PROJECT_RESPONSE=$(curl -s -X POST https://zitadel.pane.run/management/v1/projects \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Authentication Proxy"
  }')

PROJECT_ID=$(echo "$PROJECT_RESPONSE" | jq -r '.id')

if [ "$PROJECT_ID" == "null" ] || [ -z "$PROJECT_ID" ]; then
  echo "   ERROR: Failed to create project"
  echo "   Response: $PROJECT_RESPONSE"
  exit 1
fi

echo "   ✓ Project created with ID: $PROJECT_ID"

# Create OAuth2 application
echo ""
echo "4. Creating OAuth2 application..."
APP_RESPONSE=$(curl -s -X POST "https://zitadel.pane.run/management/v1/projects/$PROJECT_ID/apps/oidc" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "OAuth2-Proxy",
    "redirectUris": [
      "https://auth.pane.run/oauth2/callback",
      "https://whoami.pane.run/oauth2/callback"
    ],
    "postLogoutRedirectUris": [
      "https://zitadel.pane.run"
    ],
    "responseTypes": ["OIDC_RESPONSE_TYPE_CODE"],
    "grantTypes": ["OIDC_GRANT_TYPE_AUTHORIZATION_CODE", "OIDC_GRANT_TYPE_REFRESH_TOKEN"],
    "appType": "OIDC_APP_TYPE_WEB",
    "authMethodType": "OIDC_AUTH_METHOD_TYPE_BASIC",
    "version": "OIDC_VERSION_1_0",
    "devMode": false,
    "accessTokenType": "OIDC_TOKEN_TYPE_JWT",
    "accessTokenRoleAssertion": false,
    "idTokenRoleAssertion": false,
    "idTokenUserinfoAssertion": true,
    "clockSkew": "0s",
    "skipNativeAppSuccessPage": false
  }')

APP_CLIENT_ID=$(echo "$APP_RESPONSE" | jq -r '.clientId')
APP_CLIENT_SECRET=$(echo "$APP_RESPONSE" | jq -r '.clientSecret')

if [ "$APP_CLIENT_ID" == "null" ] || [ -z "$APP_CLIENT_ID" ]; then
  echo "   ERROR: Failed to create application"
  echo "   Response: $APP_RESPONSE"
  exit 1
fi

echo "   ✓ Application created successfully"
echo ""
echo "=== OAuth2 Application Credentials ==="
echo "Client ID:     $APP_CLIENT_ID"
echo "Client Secret: $APP_CLIENT_SECRET"

# Update the secrets.yaml file
echo ""
echo "5. Updating secrets.yaml with actual credentials..."
sed -i "s/PLACEHOLDER_CLIENT_ID/$APP_CLIENT_ID/g" /home/seupedro/homelab/k8s/auth/secrets.yaml
sed -i "s/PLACEHOLDER_CLIENT_SECRET/$APP_CLIENT_SECRET/g" /home/seupedro/homelab/k8s/auth/secrets.yaml

echo "   ✓ Secrets file updated"

# Clean up
rm -f /tmp/zitadel-sa-key.json

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "1. Apply the secrets: kubectl apply -f k8s/auth/secrets.yaml"
echo "2. Deploy OAuth2-Proxy: See k8s/auth/README.md"
