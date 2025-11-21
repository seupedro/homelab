# OAuth2-Proxy Authentication

Centralized authentication for homelab applications using OAuth2-Proxy and Zitadel.

## Status

✅ **Deployed and Operational**

- **OAuth2-Proxy**: https://auth.pane.run
- **Zitadel**: https://zitadel.pane.run
- **Client ID**: `347560624261169352`
- **Authentication Method**: OIDC with PKCE

## Quick Usage

### Protect Any Application

Add this middleware to any IngressRoute:

```yaml
middlewares:
  - name: oauth2-forward-auth
    namespace: auth
```

**Example:**

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

### Test Authentication

```bash
# Run automated test
./test-auth.sh

# Manual test
curl -I https://whoami.pane.run
# Should return 302 redirect to auth.pane.run
```

## Common Commands

### Health Checks

```bash
# OAuth2-Proxy
curl https://auth.pane.run/ping

# Zitadel
curl https://zitadel.pane.run/debug/healthz

# Pods
kubectl get pods -n auth
```

### View Logs

```bash
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy -f
```

### Restart OAuth2-Proxy

```bash
kubectl rollout restart deployment oauth2-proxy -n auth
```

### Logout

Navigate to:
```
https://auth.pane.run/oauth2/sign_out
```

## Protect Common Applications

```bash
# Kubernetes Dashboard
kubectl edit ingressroute kubernetes-dashboard -n kubernetes-dashboard

# Portainer
kubectl edit ingressroute portainer -n portainer

# Add to each:
      middlewares:
        - name: oauth2-forward-auth
          namespace: auth
```

## Authentication Headers

Protected applications receive:

```
X-Auth-Request-User: admin
X-Auth-Request-Email: admin@...
X-Auth-Request-Access-Token: eyJhbGci...
Authorization: Bearer eyJhbGci...
```

## Configuration Files

```
auth/
├── namespace.yaml              # Auth namespace
├── certificate.yaml            # TLS certificate
├── values.yaml                 # OAuth2-Proxy Helm values
├── ingressroute.yaml           # IngressRoute for auth.pane.run
├── middleware-forwardauth.yaml # ForwardAuth middleware
├── deploy.sh                   # Deployment automation
├── test-auth.sh                # Test script
├── README.md                   # This file
├── SETUP.md                    # Setup instructions
└── QUICKSTART.md               # Quick reference
```

## Session Details

- **Duration**: 7 days
- **Refresh**: Every 60 minutes
- **Cookie**: `_oauth2_proxy`
- **Scope**: `openid profile email`
- **PKCE**: Enabled (S256)

## Troubleshooting

### 500 Error

```bash
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy --tail=50
kubectl rollout restart deployment oauth2-proxy -n auth
```

### Redirect Loop

Verify redirect URI in Zitadel:
- Must be: `https://auth.pane.run/oauth2/callback`

### Certificate Issues

```bash
kubectl get certificate -n auth
kubectl describe certificate auth-tls -n auth
```

## Documentation

- **Quick Start**: [QUICKSTART.md](QUICKSTART.md)
- **Complete Guide**: [../../docs/oauth2-proxy-guide.md](../../docs/oauth2-proxy-guide.md)
- **Setup Instructions**: [SETUP.md](SETUP.md)

## Deployment

### Initial Setup

See [SETUP.md](SETUP.md) for first-time deployment instructions.

### Update Configuration

```bash
# Edit Helm values
nano values.yaml

# Upgrade deployment
helm upgrade oauth2-proxy oauth2-proxy/oauth2-proxy \
  -n auth -f values.yaml
```

## Zitadel Access

**URL**: https://zitadel.pane.run

**Credentials**:
- Username: `admin`
- Password: `5mJd7BrH&HYAiBd9D3pD1QZ^`

**Manage**:
- Users and permissions
- OAuth2 applications
- Roles and groups
- Audit logs

## Key URLs

| Service | URL | Purpose |
|---------|-----|---------|
| OAuth2-Proxy | https://auth.pane.run | Authentication gateway |
| Zitadel | https://zitadel.pane.run | Identity provider |
| Health | https://auth.pane.run/ping | Service health |
| Logout | https://auth.pane.run/oauth2/sign_out | End session |

## Examples

**Protected application**: `../whoami/ingressroute-with-auth.yaml`

**Unprotected application**: `../whoami/ingressroute.yaml`

---

**Last Updated**: 2025-11-20
