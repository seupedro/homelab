# OAuth2-Proxy Quick Start Guide

Fast reference for protecting applications with OAuth2-Proxy and Zitadel authentication.

## TL;DR

Add this to any IngressRoute to protect it:

```yaml
middlewares:
  - name: oauth2-forward-auth
    namespace: auth
```

## Current Setup

- **Zitadel**: https://zitadel.pane.run (admin / 5mJd7BrH&HYAiBd9D3pD1QZ^)
- **OAuth2-Proxy**: https://auth.pane.run
- **Middleware**: `oauth2-forward-auth` in `auth` namespace

## Protect an Application

### Option 1: Edit Existing IngressRoute

```bash
kubectl edit ingressroute <app-name> -n <namespace>
```

Add under `routes`:
```yaml
spec:
  routes:
    - kind: Rule
      match: Host(`myapp.pane.run`)
      middlewares:
        - name: oauth2-forward-auth
          namespace: auth
      services:
        - name: myapp
          port: 80
```

### Option 2: Create New IngressRoute

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
  namespace: myapp
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`myapp.pane.run`)
      middlewares:
        - name: oauth2-forward-auth
          namespace: auth
      services:
        - name: myapp
          port: 80
  tls:
    secretName: myapp-tls
```

Apply:
```bash
kubectl apply -f ingressroute.yaml
```

## Test Authentication

### Quick Test

```bash
# Should return 302 redirect
curl -I https://whoami.pane.run

# Run comprehensive test
./k8s/auth/test-auth.sh
```

### Browser Test

1. Open incognito window
2. Go to `https://whoami.pane.run`
3. Should redirect to Zitadel login
4. Login with admin credentials
5. Redirected back to whoami with auth headers

## Common Tasks

### Check Service Health

```bash
# OAuth2-Proxy health
curl https://auth.pane.run/ping

# Zitadel health
curl https://zitadel.pane.run/debug/healthz

# Check pods
kubectl get pods -n auth
kubectl get pods -n zitadel
```

### View Logs

```bash
# OAuth2-Proxy logs
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy -f

# Zitadel logs
kubectl logs -n zitadel -l app.kubernetes.io/name=zitadel -f
```

### Restart Services

```bash
# Restart OAuth2-Proxy
kubectl rollout restart deployment oauth2-proxy -n auth

# Restart Zitadel
kubectl rollout restart statefulset zitadel -n zitadel
```

### Logout

Navigate to:
```
https://auth.pane.run/oauth2/sign_out
```

## Protect Common Apps

### Kubernetes Dashboard

```bash
kubectl edit ingressroute kubernetes-dashboard -n kubernetes-dashboard
```

Add:
```yaml
      middlewares:
        - name: oauth2-forward-auth
          namespace: auth
```

### Portainer

```bash
kubectl edit ingressroute portainer -n portainer
```

Add middleware as above.

### Headlamp

```bash
kubectl edit ingressroute headlamp -n headlamp
```

Add middleware as above.

## Authentication Headers

Protected applications receive these headers:

```
X-Auth-Request-User: admin
X-Auth-Request-Email: admin@...
X-Auth-Request-Access-Token: eyJhbGci...
Authorization: Bearer eyJhbGci...
```

Use these for:
- Displaying user info
- Authorization logic
- Audit logging

## Troubleshooting

### Issue: 500 Error

```bash
# Check OAuth2-Proxy logs
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy --tail=50

# Restart OAuth2-Proxy
kubectl rollout restart deployment oauth2-proxy -n auth
```

### Issue: Redirect Loop

Check redirect URI in Zitadel:
- Must be: `https://auth.pane.run/oauth2/callback`

### Issue: Certificate Error

```bash
# Check certificate status
kubectl get certificate -n auth

# Recreate if needed
kubectl delete certificate auth-tls -n auth
kubectl apply -f certificate.yaml
```

### Issue: Not Getting Auth Headers

```bash
# Verify middleware config
kubectl describe middleware oauth2-forward-auth -n auth

# Should show authResponseHeaders
```

## Session Details

- **Duration**: 7 days
- **Refresh**: Every 60 minutes
- **Cookie Name**: `_oauth2_proxy`
- **Scope**: All `*.pane.run` domains

## Quick Deploy Commands

```bash
# Deploy OAuth2-Proxy
helm install oauth2-proxy oauth2-proxy/oauth2-proxy \
  -n auth -f values.yaml

# Apply middleware
kubectl apply -f middleware-forwardauth.yaml

# Apply certificate
kubectl apply -f certificate.yaml

# Apply IngressRoute
kubectl apply -f ingressroute.yaml
```

## Examples in Repo

- **whoami protected**: `k8s/whoami/ingressroute-with-auth.yaml`
- **whoami unprotected**: `k8s/whoami/ingressroute.yaml`
- **Middleware**: `k8s/auth/middleware-forwardauth.yaml`

## Full Documentation

For complete details, see: [docs/oauth2-proxy-guide.md](../../docs/oauth2-proxy-guide.md)

## Files in This Directory

```
auth/
├── namespace.yaml              # Auth namespace
├── certificate.yaml            # TLS certificate
├── values.yaml                 # OAuth2-Proxy Helm values
├── ingressroute.yaml           # IngressRoute for auth.pane.run
├── middleware-forwardauth.yaml # ForwardAuth middleware
├── deploy.sh                   # Deployment script
├── test-auth.sh                # Test script
├── README.md                   # Overview
├── SETUP.md                    # Setup instructions
└── QUICKSTART.md               # This file
```

## Key URLs

| Service | URL |
|---------|-----|
| Zitadel | https://zitadel.pane.run |
| OAuth2-Proxy | https://auth.pane.run |
| Health | https://auth.pane.run/ping |
| Logout | https://auth.pane.run/oauth2/sign_out |

## Need Help?

1. Check logs: `kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy`
2. Run test: `./test-auth.sh`
3. Review full guide: `docs/oauth2-proxy-guide.md`
4. Check OIDC: `curl https://zitadel.pane.run/.well-known/openid-configuration`

---

Last Updated: 2025-11-20
