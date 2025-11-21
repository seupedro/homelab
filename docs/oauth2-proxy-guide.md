# OAuth2-Proxy with Zitadel Authentication Guide

Complete guide for implementing centralized authentication in your Kubernetes homelab using OAuth2-Proxy and Zitadel.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Current Deployment Status](#current-deployment-status)
- [Prerequisites](#prerequisites)
- [Zitadel Configuration](#zitadel-configuration)
- [OAuth2-Proxy Configuration](#oauth2-proxy-configuration)
- [Protecting Applications](#protecting-applications)
- [Testing Authentication](#testing-authentication)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)
- [Monitoring and Logging](#monitoring-and-logging)
- [Quick Reference](#quick-reference)

## Overview

This homelab uses a centralized authentication system with:

- **Zitadel**: Open-source identity provider (OIDC/OAuth2)
- **OAuth2-Proxy**: Authentication gateway using ForwardAuth
- **Traefik**: Ingress controller with middleware support
- **cert-manager**: Automatic TLS certificates from Let's Encrypt

All applications can be protected by adding a single middleware reference to their IngressRoute.

## Architecture

```
Internet
    ↓
Traefik Ingress (TLS termination)
    ↓
Protected App (e.g., whoami.pane.run)
    ↓
Traefik Middleware (oauth2-forward-auth)
    ↓
OAuth2-Proxy (auth.pane.run)
    ↓
Zitadel OIDC (zitadel.pane.run)
    ↓
User Authentication
    ↓
Token Validation & Header Injection
    ↓
Application receives authenticated request
```

### Request Flow

1. User accesses `https://whoami.pane.run`
2. Traefik applies `oauth2-forward-auth` middleware
3. Middleware sends auth check to OAuth2-Proxy (internal: `http://oauth2-proxy.auth.svc.cluster.local/oauth2/auth`)
4. OAuth2-Proxy checks for valid session cookie
5. **If no session:**
   - Redirects to `https://auth.pane.run/oauth2/start`
   - Redirects to Zitadel login `https://zitadel.pane.run/oauth/v2/authorize`
   - User logs in
   - Zitadel redirects to `https://auth.pane.run/oauth2/callback` with auth code
   - OAuth2-Proxy exchanges code for tokens (PKCE flow)
   - Sets session cookie, redirects to original URL
6. **If valid session:**
   - Injects authentication headers
   - Forwards request to application
7. Application receives request with auth headers

## Current Deployment Status

### Components

| Component | Namespace | URL | Status |
|-----------|-----------|-----|--------|
| Zitadel | `zitadel` | https://zitadel.pane.run | ✅ Running |
| OAuth2-Proxy | `auth` | https://auth.pane.run | ✅ Running |
| ForwardAuth Middleware | `auth` | N/A | ✅ Configured |
| whoami (test app) | `whoami` | https://whoami.pane.run | ✅ Running |

### Zitadel Details

- **Version**: v4.7.0
- **Admin Username**: `admin`
- **Admin Password**: `5mJd7BrH&HYAiBd9D3pD1QZ^`
- **Database**: PostgreSQL 16 (postgresql-16-rw.postgres.svc.cluster.local)
- **OIDC Issuer**: `https://zitadel.pane.run`

### OAuth2-Proxy Details

- **Provider**: OIDC (Zitadel)
- **Client ID**: `347560624261169352`
- **Auth Method**: PKCE (S256)
- **Cookie Duration**: 7 days (168 hours)
- **Token Refresh**: Every 60 minutes
- **Scopes**: `openid profile email`

### File Locations

```
k8s/
├── auth/
│   ├── namespace.yaml              # Auth namespace
│   ├── certificate.yaml            # TLS for auth.pane.run
│   ├── values.yaml                 # OAuth2-Proxy Helm values
│   ├── ingressroute.yaml           # IngressRoute for auth.pane.run
│   ├── middleware-forwardauth.yaml # ForwardAuth middleware definition
│   ├── deploy.sh                   # Deployment automation
│   ├── test-auth.sh                # Test authentication flow
│   ├── README.md                   # Quick reference
│   └── SETUP.md                    # Setup instructions
│
├── zitadel/
│   ├── namespace.yaml              # Zitadel namespace
│   ├── values.yaml                 # Zitadel Helm values
│   ├── secrets.yaml                # Zitadel secrets
│   ├── certificate.yaml            # TLS for zitadel.pane.run
│   └── ingressroute.yaml           # IngressRoute for Zitadel
│
└── whoami/
    ├── deployment.yaml             # whoami app
    ├── ingressroute.yaml           # Unauthenticated route
    └── ingressroute-with-auth.yaml # Protected route
```

## Prerequisites

- Kubernetes cluster with Traefik ingress
- cert-manager with Let's Encrypt ClusterIssuer
- Helm 3
- kubectl configured
- DNS records for `*.pane.run` pointing to cluster

## Zitadel Configuration

### Accessing Zitadel Console

1. Navigate to: `https://zitadel.pane.run`
2. Login credentials:
   - Username: `admin`
   - Password: `5mJd7BrH&HYAiBd9D3pD1QZ^`

### OIDC Application Setup

Your Zitadel instance should already have an OAuth2-Proxy application configured. To verify or create:

#### 1. Create Project (if needed)

1. Go to **Projects** → **Create New Project**
2. Name: `Authentication Proxy`
3. Save

#### 2. Create Application

1. Inside the project, click **New Application**
2. Name: `OAuth2-Proxy`
3. Type: **WEB**
4. Continue

#### 3. Configure Authentication

1. **Authentication Method**: PKCE
2. **Redirect URIs**:
   ```
   https://auth.pane.run/oauth2/callback
   ```
3. **Post Logout URIs**:
   ```
   https://zitadel.pane.run
   ```
4. **Dev Mode**: Disabled (production)

#### 4. Configure Grant Types

Enable:
- ✅ Authorization Code
- ✅ Refresh Token

#### 5. Configure Scopes

The application will request these scopes:
- ✅ `openid` (required)
- ✅ `profile`
- ✅ `email`

#### 6. Note Client ID

After creation, copy the **Client ID**. Example:
```
347560624261169352
```

This Client ID must match the value configured in OAuth2-Proxy's `values.yaml`.

### OIDC Endpoints

Zitadel provides these standard OIDC endpoints:

| Endpoint | URL |
|----------|-----|
| Issuer | `https://zitadel.pane.run` |
| Discovery | `https://zitadel.pane.run/.well-known/openid-configuration` |
| Authorization | `https://zitadel.pane.run/oauth/v2/authorize` |
| Token | `https://zitadel.pane.run/oauth/v2/token` |
| UserInfo | `https://zitadel.pane.run/oidc/v1/userinfo` |
| JWKS | `https://zitadel.pane.run/oauth/v2/keys` |

### Test OIDC Discovery

```bash
curl https://zitadel.pane.run/.well-known/openid-configuration | jq
```

Expected output includes:
```json
{
  "issuer": "https://zitadel.pane.run",
  "authorization_endpoint": "https://zitadel.pane.run/oauth/v2/authorize",
  "token_endpoint": "https://zitadel.pane.run/oauth/v2/token",
  "userinfo_endpoint": "https://zitadel.pane.run/oidc/v1/userinfo",
  ...
}
```

## OAuth2-Proxy Configuration

### Helm Values Configuration

File: `k8s/auth/values.yaml`

```yaml
# Number of replicas (use 1 for cookie-based sessions)
replicaCount: 1

config:
  # OIDC Provider Configuration
  provider: "oidc"
  oidcIssuerUrl: "https://zitadel.pane.run"
  clientID: "347560624261169352"

  # Cookie Configuration
  cookieName: "_oauth2_proxy"
  cookieSecret: "gb89nUOzIWhizLfSn6jA3KY2DM9R6SopsHjWYKD72QE="
  cookieSecure: true
  cookieHttpOnly: true
  cookieSameSite: "lax"
  cookieExpire: "168h"  # 7 days
  cookieRefresh: "60m"  # Refresh every hour

  # PKCE Configuration
  codeChallengMethod: "S256"

  # Scopes
  scope: "openid profile email"

  # Forward Auth Mode
  upstreams:
    - "static://202"

  # Header Configuration
  setXAuthRequest: true
  setAuthorizationHeader: true
  passAccessToken: true
  passUserHeaders: true

  # Skip authentication for health endpoints
  skipAuthRoutes:
    - "^/ping$"
    - "^/ready$"

# Service Configuration
service:
  type: ClusterIP
  port: 80

# Resource Limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

### Key Configuration Options

#### Cookie Secret

Generate a secure cookie secret:
```bash
openssl rand -base64 32
```

Update in `values.yaml`:
```yaml
cookieSecret: "YOUR_GENERATED_SECRET_HERE"
```

#### Cookie Settings

- **cookieSecure**: Must be `true` for HTTPS
- **cookieHttpOnly**: Prevents JavaScript access (security)
- **cookieSameSite**: `lax` provides CSRF protection while allowing redirects
- **cookieExpire**: How long sessions last (168h = 7 days)
- **cookieRefresh**: How often to refresh tokens (60m = hourly)

#### PKCE (Proof Key for Code Exchange)

- **Method**: S256 (SHA-256)
- **Benefits**: Prevents authorization code interception
- **No client secret required** (though compatible with secret)

#### Upstream Configuration

```yaml
upstreams:
  - "static://202"
```

This configures forward auth mode:
- Returns HTTP 202 (Accepted) for authenticated requests
- Traefik ForwardAuth passes request to actual application
- OAuth2-Proxy doesn't proxy traffic, just validates auth

### Traefik Middleware

File: `k8s/auth/middleware-forwardauth.yaml`

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: oauth2-forward-auth
  namespace: auth
spec:
  forwardAuth:
    address: http://oauth2-proxy.auth.svc.cluster.local/oauth2/auth
    trustForwardHeader: true
    authResponseHeaders:
      - X-Auth-Request-User
      - X-Auth-Request-Email
      - X-Auth-Request-Access-Token
      - Authorization
```

#### Middleware Explanation

- **address**: Internal cluster service URL for OAuth2-Proxy auth endpoint
  - Uses `http://oauth2-proxy.auth.svc.cluster.local` for direct cluster communication
  - Avoids external routing and TLS validation issues
  - **Important**: Use internal service URL, not external `https://auth.pane.run` URL
- **trustForwardHeader**: Trust X-Forwarded headers from Traefik
- **authResponseHeaders**: Headers to pass to application

### Deploy OAuth2-Proxy

```bash
# Add Helm repository
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update

# Install OAuth2-Proxy
helm install oauth2-proxy oauth2-proxy/oauth2-proxy \
  -n auth \
  -f k8s/auth/values.yaml

# Apply middleware
kubectl apply -f k8s/auth/middleware-forwardauth.yaml

# Apply certificate and IngressRoute
kubectl apply -f k8s/auth/certificate.yaml
kubectl apply -f k8s/auth/ingressroute.yaml
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n auth

# Expected output:
# NAME                            READY   STATUS    RESTARTS   AGE
# oauth2-proxy-xxxxxxxxxx-xxxxx   1/1     Running   0          1m

# Check service
kubectl get svc -n auth

# Test health endpoint
curl https://auth.pane.run/ping
# Expected: OK

curl https://auth.pane.run/ready
# Expected: OK
```

## Protecting Applications

### Method 1: Add Middleware to Existing IngressRoute

To protect any application, add the middleware reference:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
  namespace: my-namespace
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`myapp.pane.run`)
      middlewares:
        - name: oauth2-forward-auth  # Add this
          namespace: auth              # Add this
      services:
        - name: my-app
          port: 80
  tls:
    secretName: my-app-tls
```

### Method 2: Edit Existing IngressRoute

```bash
kubectl edit ingressroute <app-name> -n <namespace>
```

Add under `routes`:
```yaml
      middlewares:
        - name: oauth2-forward-auth
          namespace: auth
```

### Example: Protect whoami

File: `k8s/whoami/ingressroute-with-auth.yaml`

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: whoami
  namespace: whoami
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`whoami.pane.run`)
      middlewares:
        - name: oauth2-forward-auth
          namespace: auth
      services:
        - name: whoami
          port: 80
  tls:
    secretName: whoami-tls
```

Apply:
```bash
kubectl apply -f k8s/whoami/ingressroute-with-auth.yaml
```

### Protect Multiple Applications

Quick commands to protect common homelab applications:

```bash
# Kubernetes Dashboard
kubectl edit ingressroute kubernetes-dashboard -n kubernetes-dashboard

# Portainer
kubectl edit ingressroute portainer -n portainer

# Headlamp
kubectl edit ingressroute headlamp -n headlamp

# Add to each:
      middlewares:
        - name: oauth2-forward-auth
          namespace: auth
```

### Template for New Applications

When deploying new applications using `scripts/deploy-app.sh`, include middleware in the template:

File: `k8s/templates/ingressroute.yaml`

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: {{APP_NAME}}
  namespace: {{APP_NAME}}
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`{{SUBDOMAIN}}.pane.run`)
      middlewares:
        - name: oauth2-forward-auth
          namespace: auth
      services:
        - name: {{APP_NAME}}
          port: {{PORT}}
  tls:
    secretName: {{APP_NAME}}-tls
```

## Testing Authentication

### Test Authentication Flow

```bash
# Run comprehensive test
/home/seupedro/homelab/k8s/auth/test-auth.sh
```

### Manual Testing

#### 1. Test Unauthenticated Access

```bash
curl -I https://whoami.pane.run
```

Expected response:
```
HTTP/2 302
location: https://auth.pane.run/oauth2/start?rd=https%3A%2F%2Fwhoami.pane.run
```

#### 2. Test in Browser

1. Open **incognito/private window**
2. Navigate to: `https://whoami.pane.run`
3. Observe redirect chain:
   - → `https://auth.pane.run/oauth2/start...`
   - → `https://zitadel.pane.run/oauth/v2/authorize...`
4. Login with Zitadel credentials
5. After login, redirected back to whoami
6. whoami displays authentication headers

#### 3. Verify Authentication Headers

After authentication, whoami should display:

```
X-Auth-Request-User: admin
X-Auth-Request-Email: admin@...
X-Auth-Request-Access-Token: eyJhbGciOiJS...
Authorization: Bearer eyJhbGciOiJS...
X-Forwarded-User: admin
X-Forwarded-Email: admin@...
```

Applications can use these headers for:
- Display user information
- Authorization decisions
- Audit logging
- API calls with user context

#### 4. Test Session Persistence

1. Close browser tab
2. Reopen: `https://whoami.pane.run`
3. Should access directly (no login prompt)
4. Session valid for 7 days

#### 5. Test Logout

Navigate to:
```
https://auth.pane.run/oauth2/sign_out
```

Or with redirect:
```
https://auth.pane.run/oauth2/sign_out?rd=https://zitadel.pane.run
```

#### 6. Test Multiple Applications

If multiple apps are protected:
1. Login to one app
2. Access another protected app
3. Should access directly (single sign-on)
4. One session works for all apps

## Troubleshooting

### Issue: 500 Internal Server Error

**Symptoms:**
- Protected app returns HTTP 500
- OAuth2-Proxy logs show errors

**Check logs:**
```bash
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy --tail=100
```

**Common causes:**

1. **OIDC issuer unreachable**
   ```bash
   # Test OIDC discovery
   curl https://zitadel.pane.run/.well-known/openid-configuration
   ```

2. **Invalid client ID**
   ```bash
   # Verify in values.yaml matches Zitadel
   kubectl get configmap -n auth -o yaml | grep clientID
   ```

3. **Zitadel not ready**
   ```bash
   kubectl get pods -n zitadel
   curl https://zitadel.pane.run/debug/healthz
   ```

**Fix:**
```bash
# Restart OAuth2-Proxy
kubectl rollout restart deployment oauth2-proxy -n auth

# Wait for ready
kubectl rollout status deployment oauth2-proxy -n auth
```

### Issue: Redirect Loop

**Symptoms:**
- Browser redirects continuously
- Never reaches login page

**Check:**
```bash
# Verify middleware configuration
kubectl describe middleware oauth2-forward-auth -n auth

# Check IngressRoute
kubectl describe ingressroute <app> -n <namespace>
```

**Common causes:**

1. **Incorrect redirect URI in Zitadel**
   - Must be: `https://auth.pane.run/oauth2/callback`

2. **Cookie domain mismatch**
   - Check cookie settings in values.yaml

3. **Middleware not properly applied**
   ```bash
   # Middleware must be in 'auth' namespace
   kubectl get middleware -n auth
   ```

**Fix:**
```bash
# Reapply middleware
kubectl apply -f k8s/auth/middleware-forwardauth.yaml

# Restart OAuth2-Proxy
kubectl rollout restart deployment oauth2-proxy -n auth
```

### Issue: 401 Unauthorized After Login

**Symptoms:**
- Login succeeds in Zitadel
- Redirect back shows 401

**Check:**
```bash
# Watch logs during login attempt
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy -f
```

**Common causes:**

1. **Token validation failure**
   - Check OIDC discovery working
   - Verify JWKS endpoint accessible

2. **Missing scopes**
   - Ensure `openid profile email` requested
   - Check Zitadel grants these scopes

3. **Clock skew**
   - Ensure system time synchronized

**Fix:**
```bash
# Verify OIDC endpoints
curl https://zitadel.pane.run/oauth/v2/keys | jq

# Check OAuth2-Proxy can reach Zitadel
kubectl exec -it -n auth deploy/oauth2-proxy -- \
  wget -O- https://zitadel.pane.run/.well-known/openid-configuration
```

### Issue: Certificate Errors

**Symptoms:**
- Browser shows certificate warnings
- `https://auth.pane.run` not trusted

**Check:**
```bash
# Check certificate status
kubectl get certificate -n auth

# Expected:
# NAME        READY   SECRET      AGE
# auth-tls    True    auth-tls    1h

# If not ready, describe:
kubectl describe certificate auth-tls -n auth
```

**Common causes:**

1. **DNS not propagated**
   ```bash
   nslookup auth.pane.run
   ```

2. **Let's Encrypt rate limit**
   - Check cert-manager logs

3. **ClusterIssuer misconfigured**
   ```bash
   kubectl get clusterissuer
   ```

**Fix:**
```bash
# Delete and recreate certificate
kubectl delete certificate auth-tls -n auth
kubectl apply -f k8s/auth/certificate.yaml

# Monitor progress
kubectl get certificate -n auth -w

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50
```

### Issue: Headers Not Passed to Application

**Symptoms:**
- App doesn't receive X-Auth-Request-* headers
- Can't identify logged-in user

**Check:**
```bash
# Verify middleware has authResponseHeaders
kubectl get middleware oauth2-forward-auth -n auth -o yaml
```

**Should include:**
```yaml
spec:
  forwardAuth:
    authResponseHeaders:
      - X-Auth-Request-User
      - X-Auth-Request-Email
      - X-Auth-Request-Access-Token
      - Authorization
```

**Fix:**
```bash
# Reapply middleware with correct headers
kubectl apply -f k8s/auth/middleware-forwardauth.yaml
```

### Debug Commands

**View all auth components:**
```bash
kubectl get all,middleware,certificate,ingressroute -n auth
```

**Test OAuth2-Proxy health:**
```bash
curl https://auth.pane.run/ping
curl https://auth.pane.run/ready
```

**Test Zitadel health:**
```bash
curl https://zitadel.pane.run/debug/healthz
curl https://zitadel.pane.run/.well-known/openid-configuration
```

**Follow logs:**
```bash
# OAuth2-Proxy
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy -f

# Zitadel
kubectl logs -n zitadel -l app.kubernetes.io/name=zitadel -f

# Traefik
kubectl logs -n traefik -l app.kubernetes.io/name=traefik -f
```

## Advanced Configuration

### Multi-Replica with Redis

For high availability, use Redis for session storage.

#### Deploy Redis

File: `k8s/auth/redis.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: auth
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: auth
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
```

#### Update OAuth2-Proxy Values

```yaml
replicaCount: 3

sessionStorage:
  type: redis
  redis:
    clientType: standalone
    standalone:
      connectionUrl: redis://redis.auth.svc.cluster.local:6379
```

#### Apply Changes

```bash
kubectl apply -f k8s/auth/redis.yaml

helm upgrade oauth2-proxy oauth2-proxy/oauth2-proxy \
  -n auth \
  -f k8s/auth/values.yaml
```

### Email Domain Restrictions

Restrict authentication to specific domains:

```yaml
config:
  emailDomains:
    - "pane.run"
    - "example.com"
```

Only users with emails from these domains can authenticate.

### Group-Based Authorization

Implement role-based access control.

#### In OAuth2-Proxy

```yaml
extraArgs:
  allowed-groups:
    - "admin-group"
    - "developers-group"
```

#### In Zitadel

1. Create roles/groups
2. Assign users to groups
3. Configure groups claim in OIDC token
4. Map to OAuth2-Proxy groups

### Skip Authentication for Paths

Allow public access to specific paths:

```yaml
extraArgs:
  skip-auth-regex:
    - "^/health$"
    - "^/metrics$"
    - "^/api/public/.*"
```

Useful for:
- Health check endpoints
- Public API routes
- Static assets

### Custom Login Page Branding

```yaml
config:
  customSignInLogo: "https://yourlogo.com/logo.png"

extraArgs:
  footer: "Authentication required - Contact admin@pane.run"
```

### Whitelist Internal IPs

Allow direct access from cluster-internal IPs:

```yaml
extraArgs:
  whitelist-domains:
    - ".cluster.local"

  trusted-ips:
    - "10.0.0.0/8"
    - "172.16.0.0/12"
    - "192.168.0.0/16"
```

## Monitoring and Logging

### Prometheus Metrics

OAuth2-Proxy exposes metrics for Prometheus.

#### Enable Metrics

```yaml
metrics:
  enabled: true
  port: 44180
  servicemonitor:
    enabled: true
    namespace: auth
```

#### Key Metrics

- `oauth2_proxy_requests_total` - Total requests
- `oauth2_proxy_authentication_attempts_total` - Auth attempts
- `oauth2_proxy_authentication_failures_total` - Auth failures
- `oauth2_proxy_upstream_requests_total` - Upstream requests

#### Grafana Dashboard

If Grafana is installed:
1. Import dashboard ID: **9519** (OAuth2 Proxy Stats)
2. Select Prometheus data source
3. Customize for your environment

### Logging Configuration

#### Adjust Log Level

```yaml
extraArgs:
  logging-level: "info"  # debug, info, warn, error
  standard-logging: true
  auth-logging: true
  request-logging: true
```

Use `debug` for troubleshooting, `info` for production.

#### View Logs

```bash
# Real-time logs
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy -f

# Search for failures
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy | grep "authentication failed"

# Export logs
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy --since=1h > oauth2-logs.txt
```

### Audit Logging

Track authentication events:

```yaml
extraArgs:
  auth-logging: true
  request-logging: true
```

Logs include:
- Authentication attempts
- User logins/logouts
- Failed authentications
- Token refreshes

## Quick Reference

### Common Commands

#### Deployment

```bash
# Install OAuth2-Proxy
helm install oauth2-proxy oauth2-proxy/oauth2-proxy \
  -n auth -f k8s/auth/values.yaml

# Upgrade OAuth2-Proxy
helm upgrade oauth2-proxy oauth2-proxy/oauth2-proxy \
  -n auth -f k8s/auth/values.yaml

# Apply middleware
kubectl apply -f k8s/auth/middleware-forwardauth.yaml
```

#### Verification

```bash
# Check health
curl https://auth.pane.run/ping
curl https://zitadel.pane.run/debug/healthz

# Check pods
kubectl get pods -n auth
kubectl get pods -n zitadel

# Check certificates
kubectl get certificate -n auth
kubectl get certificate -n zitadel

# Run tests
/home/seupedro/homelab/k8s/auth/test-auth.sh
```

#### Troubleshooting

```bash
# View logs
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy -f

# Restart OAuth2-Proxy
kubectl rollout restart deployment oauth2-proxy -n auth

# Delete certificate
kubectl delete certificate auth-tls -n auth
kubectl apply -f k8s/auth/certificate.yaml

# Check OIDC
curl https://zitadel.pane.run/.well-known/openid-configuration | jq
```

#### Protect Application

```bash
# Edit IngressRoute
kubectl edit ingressroute <app-name> -n <namespace>

# Add middleware:
      middlewares:
        - name: oauth2-forward-auth
          namespace: auth

# Or apply new IngressRoute
kubectl apply -f k8s/apps/<app>/ingressroute-with-auth.yaml
```

### Important URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Zitadel Admin | https://zitadel.pane.run | Identity management |
| OAuth2-Proxy | https://auth.pane.run | Authentication gateway |
| Health Check | https://auth.pane.run/ping | Service health |
| Logout | https://auth.pane.run/oauth2/sign_out | End session |
| OIDC Discovery | https://zitadel.pane.run/.well-known/openid-configuration | OIDC metadata |

### Authentication Headers

Applications receive these headers:

| Header | Description | Example |
|--------|-------------|---------|
| `X-Auth-Request-User` | Username | `admin` |
| `X-Auth-Request-Email` | Email address | `admin@pane.run` |
| `X-Auth-Request-Access-Token` | JWT access token | `eyJhbGci...` |
| `Authorization` | Bearer token | `Bearer eyJhbGci...` |

### Session Management

- **Cookie Name**: `_oauth2_proxy`
- **Duration**: 7 days (168 hours)
- **Refresh Interval**: 60 minutes
- **Secure**: HTTPS only
- **HttpOnly**: Not accessible via JavaScript
- **SameSite**: Lax (CSRF protection)

### Security Best Practices

1. **Use PKCE** (already configured)
2. **Enable HTTPS only** (cookieSecure: true)
3. **Set HttpOnly cookies** (prevents XSS)
4. **Use SameSite=lax** (CSRF protection)
5. **Rotate cookie secret** periodically
6. **Monitor failed auth attempts**
7. **Use group-based authorization** for sensitive apps
8. **Implement email domain restrictions**
9. **Keep OAuth2-Proxy updated**
10. **Regular security audits**

## Backup and Migration

### Backup Configuration

```bash
# Backup auth namespace
kubectl get all,secret,configmap,certificate,ingressroute,middleware \
  -n auth -o yaml > auth-backup-$(date +%Y%m%d).yaml

# Backup Zitadel
kubectl get all,secret,configmap,certificate,ingressroute \
  -n zitadel -o yaml > zitadel-backup-$(date +%Y%m%d).yaml

# Backup Helm values
helm get values oauth2-proxy -n auth > oauth2-values-backup.yaml
```

### Restore Configuration

```bash
kubectl apply -f auth-backup-YYYYMMDD.yaml
kubectl apply -f zitadel-backup-YYYYMMDD.yaml
```

### Migrate to New Cluster

```bash
# Export from old cluster
helm get values oauth2-proxy -n auth > values.yaml
kubectl get secret -n auth -o yaml > secrets.yaml

# Import to new cluster
kubectl create namespace auth
kubectl apply -f secrets.yaml
helm install oauth2-proxy oauth2-proxy/oauth2-proxy \
  -n auth -f values.yaml
```

## Summary

### What You Have

✅ Zitadel identity provider at `https://zitadel.pane.run`
✅ OAuth2-Proxy authentication gateway at `https://auth.pane.run`
✅ Traefik ForwardAuth middleware configured
✅ Test application (whoami) with protected route available
✅ Automated deployment and testing scripts
✅ Complete TLS certificates via Let's Encrypt

### How It Works

1. Add middleware to any IngressRoute
2. User accesses protected application
3. Traefik redirects to OAuth2-Proxy
4. OAuth2-Proxy redirects to Zitadel login
5. User authenticates with Zitadel
6. OAuth2-Proxy validates token, sets session cookie
7. User redirected to application with auth headers
8. Session valid for 7 days across all protected apps

### Next Steps

1. Test authentication flow on whoami
2. Protect additional applications (dashboard, portainer, etc.)
3. Create additional Zitadel users for team members
4. Configure group-based authorization if needed
5. Set up monitoring and alerts
6. Document application-specific authorization logic

### Support

- **OAuth2-Proxy Docs**: https://oauth2-proxy.github.io/oauth2-proxy/
- **Zitadel Docs**: https://zitadel.com/docs
- **Traefik ForwardAuth**: https://doc.traefik.io/traefik/middlewares/http/forwardauth/
- **Test Script**: `/home/seupedro/homelab/k8s/auth/test-auth.sh`
- **Deployment Script**: `/home/seupedro/homelab/k8s/auth/deploy.sh`

---

**Last Updated**: 2025-11-20
**Author**: Homelab Infrastructure Team
**Version**: 1.0
