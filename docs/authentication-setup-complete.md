# 🎉 OAuth2-Proxy Authentication Setup - COMPLETE!

**Date**: 2025-11-20
**Status**: ✅ **WORKING**

## What We Accomplished

Successfully configured OAuth2-Proxy with Zitadel OIDC authentication for the whoami application using **Reverse Proxy mode**.

### Working Authentication Flow

1. ✅ User visits `https://whoami.pane.run`
2. ✅ OAuth2-Proxy shows "Sign in with OpenID Connect" page
3. ✅ User clicks sign in → Redirects to Zitadel login
4. ✅ User authenticates with Zitadel
5. ✅ Redirects back to whoami.pane.run
6. ✅ OAuth2-Proxy proxies authenticated request to whoami service
7. ✅ **Success!** User sees the whoami page content

## Architecture Overview

```
Browser Request (whoami.pane.run)
    ↓
Traefik (externalIPs: 94.130.181.89)
    ↓
OAuth2-Proxy (auth namespace)
    ├─ Check authentication
    ├─ Not authenticated? → Redirect to Zitadel
    ├─ After login? → Set cookie, proxy to whoami
    └─ Authenticated? → Proxy to whoami
        ↓
Whoami Service (whoami namespace)
```

## Key Components

### 1. OAuth2-Proxy Configuration

- **Mode**: Reverse Proxy (not ForwardAuth)
- **Provider**: OpenID Connect (Zitadel)
- **OIDC Issuer**: `https://zitadel.pane.run`
- **Client ID**: `347560624261169352`
- **Redirect URL**: `https://whoami.pane.run/oauth2/callback`
- **Upstream**: `http://whoami.whoami.svc.cluster.local:80`
- **PKCE**: Enabled (S256 code challenge)

### 2. Traefik Configuration

- **Networking**: externalIPs mode (not hostNetwork)
- **External IP**: `94.130.181.89`
- **DNS Resolution**: ✅ Works (can resolve service names)
- **Security**: Runs as non-root (UID 65532)

### 3. Zitadel Configuration

- **Issuer**: `https://zitadel.pane.run`
- **Application**: Web application with PKCE
- **Redirect URI**: `https://whoami.pane.run/oauth2/callback` ✅
- **Scopes**: `openid`, `profile`, `email`

## Files Created/Modified

### New Files

1. `/home/seupedro/homelab/docs/oauth2-proxy-reverse-proxy-mode.md`
   - Complete reverse proxy architecture documentation
   - Troubleshooting guide
   - Configuration examples

2. `/home/seupedro/homelab/k8s/whoami/ingressroute-reverse-proxy.yaml`
   - IngressRoute routing to OAuth2-Proxy service

3. `/home/seupedro/homelab/docs/authentication-setup-complete.md`
   - This file (summary)

### Modified Files

1. `/home/seupedro/homelab/k8s/auth/values.yaml`
   - Updated to reverse proxy mode
   - Added whoami upstream
   - Configured extraArgs with all OIDC settings

2. `/home/seupedro/homelab/CLAUDE.md`
   - Updated authentication architecture section
   - Added reverse proxy vs ForwardAuth comparison
   - Updated repository structure

3. `/home/seupedro/homelab/k8s/auth/middleware-forwardauth.yaml`
   - ForwardAuth middleware (for API use cases)

## Journey Summary

### Challenge 1: ForwardAuth Returns 401
**Problem**: Using ForwardAuth middleware, OAuth2-Proxy returned 401 instead of redirecting to login page.

**Solution**: Switched to Reverse Proxy mode where OAuth2-Proxy handles the full authentication flow.

### Challenge 2: DNS Resolution Issues
**Problem**: Traefik with `hostNetwork: true` couldn't resolve Kubernetes service names.

**Solution**: Migrated Traefik to externalIPs Service, enabling proper DNS resolution.

### Challenge 3: Redirecting to Google
**Problem**: OAuth2-Proxy was redirecting to Google OAuth instead of Zitadel.

**Solution**: Added OIDC configuration in `extraArgs` to properly configure the OIDC provider.

### Challenge 4: 404 After Authentication
**Problem**: After successful login, OAuth2-Proxy returned 404.

**Solution**: Added `upstream` configuration in extraArgs to proxy to whoami service.

## Testing

### Quick Test

```bash
# Check OAuth2-Proxy is running
kubectl get pods -n auth -l app=oauth2-proxy

# Check configuration
kubectl logs -n auth -l app=oauth2-proxy | grep "mapping path"
# Should show: mapping path "/" => upstream "http://whoami.whoami.svc.cluster.local:80"

# Test in browser
# 1. Open https://whoami.pane.run
# 2. Should see "Sign in with OpenID Connect" page
# 3. Click sign in → redirects to Zitadel
# 4. After login → shows whoami page content
```

### Verify Components

```bash
# Traefik externalIP
kubectl get svc traefik -n traefik
# Should show EXTERNAL-IP: 94.130.181.89

# OAuth2-Proxy service
kubectl get svc oauth2-proxy -n auth

# Whoami service
kubectl get svc whoami -n whoami

# IngressRoute
kubectl get ingressroute whoami -n whoami -o yaml
# Should route to oauth2-proxy service (not whoami)
```

## Protecting Additional Applications

### Option 1: Separate OAuth2-Proxy Instance (Recommended)

For each application, deploy a separate OAuth2-Proxy instance:

```bash
# 1. Copy and modify values.yaml
cp k8s/auth/values.yaml k8s/myapp/oauth2-values.yaml

# Edit:
# - redirectUrl: https://myapp.pane.run/oauth2/callback
# - upstream: http://myapp.myapp.svc.cluster.local:80

# 2. Deploy
helm install oauth2-proxy-myapp oauth2-proxy/oauth2-proxy \
  -n myapp \
  -f k8s/myapp/oauth2-values.yaml

# 3. Create IngressRoute routing to oauth2-proxy-myapp service

# 4. Add redirect URL to Zitadel
```

### Option 2: ForwardAuth Middleware (For APIs)

For API endpoints that don't need browser redirects:

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

This will return 401 for unauthenticated API calls.

## Key Learnings

1. **ForwardAuth vs Reverse Proxy**: ForwardAuth is for APIs (returns status codes), Reverse Proxy is for browsers (returns HTML/redirects)

2. **OAuth2-Proxy Configuration**: Helm chart `config` section doesn't always work; use `extraArgs` for reliable configuration

3. **Redirect URLs**: Must match the domain where OAuth2-Proxy is accessed (e.g., `whoami.pane.run/oauth2/callback`, not `auth.pane.run/oauth2/callback`)

4. **Upstream Configuration**: Must be explicitly set in extraArgs for reverse proxy mode

5. **Traefik Networking**: externalIPs works great for single-node clusters, providing DNS resolution without hostNetwork issues

## Documentation

- **Comprehensive Guide**: `/home/seupedro/homelab/docs/oauth2-proxy-reverse-proxy-mode.md`
- **Traefik Migration**: `/home/seupedro/homelab/docs/traefik-externalips-migration.md`
- **Project Documentation**: `/home/seupedro/homelab/CLAUDE.md`

## Useful Commands

```bash
# View OAuth2-Proxy logs
kubectl logs -n auth -l app=oauth2-proxy --tail=100 -f

# Check authentication flow
kubectl logs -n auth -l app=oauth2-proxy | grep "AuthSuccess\|Initiating login"

# Test redirect to Zitadel
curl -I https://whoami.pane.run/oauth2/start?rd=/

# Check Traefik routing
kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=50

# Get all IngressRoutes
kubectl get ingressroute -A
```

## What's Next?

Now that authentication is working, you can:

1. **Protect more applications**: Use the same pattern for other services
2. **Customize authentication**: Add role-based access control (RBAC)
3. **Monitor sessions**: Track user authentication events
4. **Add logout functionality**: Configure post-logout redirect URIs
5. **Fine-tune security**: Adjust cookie expiration, session storage, etc.

---

**🎉 Congratulations on setting up a production-ready OAuth2 authentication system!**

**Contact**: hartmnn.p@gmail.com (authenticated user)
**Cluster**: pane-homelab (Hetzner Cloud)
**Provider**: Zitadel (self-hosted)
