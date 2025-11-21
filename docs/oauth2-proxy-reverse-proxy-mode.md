# OAuth2-Proxy Reverse Proxy Mode Configuration

**Date**: 2025-11-20
**Mode**: Reverse Proxy (Browser-based authentication with redirects)
**Status**: ✅ Working

## Overview

OAuth2-Proxy is configured in **Reverse Proxy mode** to provide browser-based authentication with proper redirects to Zitadel login page. This is the correct architecture for web applications accessed by browsers.

## Architecture

### Request Flow

```
Browser Request
    ↓
Traefik Ingress (whoami.pane.run)
    ↓
OAuth2-Proxy (auth namespace)
    ├─ Not authenticated? → Redirect to Zitadel login
    │                       ↓
    │                    User logs in
    │                       ↓
    │                    Redirect back to OAuth2-Proxy
    │                       ↓
    └─ Authenticated! → Proxy request to whoami service
                            ↓
                        Return response to browser
```

### Key Components

1. **Traefik IngressRoute**: Routes `whoami.pane.run` to OAuth2-Proxy (NOT directly to whoami)
2. **OAuth2-Proxy**: Handles authentication and proxies to backend service
3. **Zitadel**: OIDC provider for authentication
4. **Whoami Service**: Backend application (protected)

## Configuration Files

### OAuth2-Proxy Helm Values

**File**: `/home/seupedro/homelab/k8s/auth/values.yaml`

Key configurations:
- **Provider**: `oidc` (OpenID Connect)
- **OIDC Issuer**: `https://zitadel.pane.run`
- **Redirect URL**: `https://whoami.pane.run/oauth2/callback` (must match application domain)
- **Upstream**: `http://whoami.whoami.svc.cluster.local:80` (backend service to proxy to)
- **PKCE**: Enabled with S256 code challenge method

### IngressRoute Configuration

**File**: `/home/seupedro/homelab/k8s/whoami/ingressroute-reverse-proxy.yaml`

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
          # NO middlewares - OAuth2-Proxy handles auth internally
          services:
              # Route to OAuth2-Proxy, NOT directly to whoami
              - name: oauth2-proxy
                namespace: auth
                port: 80
    tls:
        secretName: whoami-tls
```

**Important**: The IngressRoute routes to `oauth2-proxy` service, not to `whoami` service!

### Zitadel Configuration

**Application Client ID**: `347560624261169352`

**Required Settings**:
- Application Type: Web
- Authentication Method: PKCE
- Redirect URIs: `https://whoami.pane.run/oauth2/callback`
- Post Logout Redirect URIs: `https://whoami.pane.run`
- Allowed Scopes: `openid`, `profile`, `email`

## Authentication Flow Details

### 1. Unauthenticated Request

```bash
curl -I https://whoami.pane.run
HTTP/2 403
```

Browser receives HTML sign-in page with "Sign in with OpenID Connect" button.

### 2. Initiate Login

User clicks "Sign in" button → `GET /oauth2/start?rd=/`

OAuth2-Proxy returns:
```
HTTP/2 302
Location: https://zitadel.pane.run/oauth/v2/authorize?client_id=...&redirect_uri=https://whoami.pane.run/oauth2/callback&...
```

### 3. Zitadel Authentication

User logs in at Zitadel → Zitadel redirects back:
```
https://whoami.pane.run/oauth2/callback?code=...&state=...
```

### 4. OAuth2-Proxy Callback

OAuth2-Proxy:
1. Exchanges authorization code for tokens (using PKCE)
2. Validates ID token
3. Sets authentication cookie (`_oauth2-proxy`)
4. Redirects to original URL (`/`)

### 5. Authenticated Request

Browser sends request with cookie → OAuth2-Proxy:
1. Validates cookie/session
2. Proxies request to `http://whoami.whoami.svc.cluster.local:80`
3. Returns whoami response to browser

**Success!** User sees the whoami page.

## Reverse Proxy vs ForwardAuth Mode

### ForwardAuth Mode (API-focused)

**Architecture**:
```
Browser → Traefik → [Auth Check to OAuth2-Proxy] → Backend Service
                     ↓
                  Returns 401 (no redirect)
```

**Characteristics**:
- OAuth2-Proxy `/oauth2/auth` endpoint returns only status codes (202/401)
- Never returns redirects
- Good for: API authentication, machine-to-machine
- Bad for: Browser-based applications

### Reverse Proxy Mode (Browser-focused) ✅

**Architecture**:
```
Browser → Traefik → OAuth2-Proxy → [Checks auth, redirects if needed] → Backend Service
```

**Characteristics**:
- OAuth2-Proxy handles full authentication flow
- Returns HTML sign-in pages and redirects to OIDC provider
- Good for: Browser-based web applications
- This is what we're using!

## Protecting Additional Applications

To protect another application with OAuth2-Proxy:

### Option 1: Shared OAuth2-Proxy Instance (Current)

Each application needs its own OAuth2-Proxy deployment because the redirect URL and upstream are application-specific.

### Option 2: Per-Application OAuth2-Proxy Deployment

Create a new OAuth2-Proxy deployment for each application:

1. Copy `/home/seupedro/homelab/k8s/auth/values.yaml` to a new file
2. Update:
   - `redirectUrl`: `https://myapp.pane.run/oauth2/callback`
   - `upstreams`: `http://myapp.myapp.svc.cluster.local:80`
3. Deploy with a new release name:
   ```bash
   helm install oauth2-proxy-myapp oauth2-proxy/oauth2-proxy \
     -n myapp \
     -f values-myapp.yaml
   ```
4. Create IngressRoute routing to the new OAuth2-Proxy instance
5. Add redirect URL to Zitadel application

### Option 3: ForwardAuth Middleware (For APIs)

For API endpoints that don't need browser redirects, you can use the existing ForwardAuth middleware:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
    name: my-api
spec:
    routes:
        - match: Host(`api.pane.run`)
          middlewares:
            - name: oauth2-forward-auth
              namespace: auth
          services:
            - name: my-api
              port: 80
```

This will return 401 for unauthenticated requests (good for APIs).

## Testing

### Check OAuth2-Proxy Status

```bash
# Check pods
kubectl get pods -n auth -l app=oauth2-proxy

# Check logs
kubectl logs -n auth -l app=oauth2-proxy --tail=50

# Verify upstream configuration
kubectl logs -n auth -l app=oauth2-proxy | grep "mapping path"
# Should show: mapping path "/" => upstream "http://whoami.whoami.svc.cluster.local:80"
```

### Test Authentication Flow

```bash
# 1. Check unauthenticated access (should show sign-in page)
curl -s https://whoami.pane.run | grep "Sign in"

# 2. Check OAuth2 start endpoint (should redirect to Zitadel)
curl -I https://whoami.pane.run/oauth2/start?rd=/
# Should return: HTTP/2 302
# Location: https://zitadel.pane.run/oauth/v2/authorize...

# 3. Test with browser
# Open https://whoami.pane.run in browser
# Should redirect to Zitadel login
# After login, should show whoami page
```

### Verify IngressRoute

```bash
kubectl get ingressroute whoami -n whoami -o yaml

# Should route to oauth2-proxy service, NOT whoami service
# services:
#   - name: oauth2-proxy
#     namespace: auth
#     port: 80
```

## Troubleshooting

### Issue: Still seeing 401 instead of sign-in page

**Cause**: Using ForwardAuth middleware instead of routing to OAuth2-Proxy

**Solution**: Update IngressRoute to route to `oauth2-proxy` service (not use middleware)

### Issue: 404 after successful login

**Cause**: OAuth2-Proxy upstream not configured correctly

**Solution**:
```bash
# Check upstream in OAuth2-Proxy logs
kubectl logs -n auth -l app=oauth2-proxy | grep "mapping path"

# Should show correct backend service URL
# If showing "file:///dev/null", update values.yaml extraArgs.upstream
```

### Issue: Redirects to Google instead of Zitadel

**Cause**: OIDC issuer URL not configured

**Solution**: Verify OAuth2-Proxy logs show:
```
OAuthProxy configured for OpenID Connect
```
Not:
```
OAuthProxy configured for Google
```

If showing Google, add to `extraArgs`:
```yaml
extraArgs:
  provider: "oidc"
  oidc-issuer-url: "https://zitadel.pane.run"
```

### Issue: "Invalid redirect URI" from Zitadel

**Cause**: Redirect URL not registered in Zitadel

**Solution**: Add `https://whoami.pane.run/oauth2/callback` to Zitadel application redirect URIs

### Issue: Cookie not being set

**Cause**: Cookie domain mismatch or secure cookie issues

**Solution**: Verify OAuth2-Proxy cookie settings:
```yaml
extraArgs:
  cookie-secure: true      # For HTTPS
  cookie-httponly: true
  cookie-samesite: "lax"
```

## Benefits of This Architecture

✅ **Browser-Friendly**: Proper redirects to login page
✅ **User Experience**: No confusing 401 errors
✅ **Session Management**: OAuth2-Proxy handles sessions and token refresh
✅ **Backend Agnostic**: Backend service doesn't need auth logic
✅ **Centralized Auth**: Single OAuth2-Proxy config for multiple apps
✅ **PKCE Security**: Secure authorization code flow

## Files Modified

1. `/home/seupedro/homelab/k8s/auth/values.yaml` - OAuth2-Proxy configuration
2. `/home/seupedro/homelab/k8s/whoami/ingressroute-reverse-proxy.yaml` - IngressRoute
3. Zitadel application - Added redirect URL

## Next Steps

To protect additional applications:

1. **Deploy separate OAuth2-Proxy instance per application** (recommended for production)
2. **Configure application-specific redirect URLs** in Zitadel
3. **Update IngressRoutes** to route through OAuth2-Proxy
4. **Test authentication flow** for each protected application

---

**Author**: Claude Code
**Reference**: [OAuth2-Proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
