# OAuth2-Proxy Setup for Traefik Dashboard

This guide explains how to protect the Traefik dashboard with OAuth2-Proxy using Zitadel as the OIDC provider.

## Architecture

The setup uses **Reverse Proxy Mode**:
1. Browser accesses `traefik.pane.run`
2. Traefik routes request to OAuth2-Proxy (deployed in traefik namespace)
3. OAuth2-Proxy checks authentication:
   - Not authenticated? → Shows "Sign in with OpenID Connect" page → Redirects to Zitadel
4. After successful Zitadel login → OAuth2-Proxy proxies request to Traefik dashboard
5. User sees the Traefik dashboard (authenticated)

## Prerequisites

1. Zitadel running at `https://zitadel.pane.run`
2. Traefik dashboard enabled (already configured in `values-externalips.yaml`)
3. Helm repository for OAuth2-Proxy

## Step 1: Create Zitadel Application

1. Log in to Zitadel at `https://zitadel.pane.run`
2. Navigate to your organization
3. Go to **Applications** → **New**
4. Configure:
   - **Name**: `Traefik Dashboard`
   - **Type**: `Web`
   - **Authentication Method**: `PKCE` (Public Client)
5. Set **Redirect URIs**:
   - `https://traefik.pane.run/oauth2/callback`
6. Set **Post Logout URIs**:
   - `https://traefik.pane.run`
7. **Save** the application
8. Copy the **Client ID** (you'll need this for the next step)

## Step 2: Update OAuth2-Proxy Values

Edit `k8s/infra/traefik/oauth2-proxy-values.yaml`:

```yaml
config:
    clientID: "YOUR_CLIENT_ID_FROM_ZITADEL"
```

Replace `YOUR_CLIENT_ID_FROM_ZITADEL` with the Client ID from Step 1.

The cookie secret has already been generated: `OjvWGApwruDco8QXgAvZG06J/Mr+HCHf+OsNzuPQ6Qc=`

## Step 3: Add Helm Repository

```bash
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update
```

## Step 4: Deploy OAuth2-Proxy

```bash
helm install oauth2-proxy-traefik oauth2-proxy/oauth2-proxy \
  -n traefik \
  -f k8s/infra/traefik/oauth2-proxy-values.yaml
```

## Step 5: Update Traefik Dashboard IngressRoute

The IngressRoute needs to be updated to route to OAuth2-Proxy instead of directly to the Traefik API.

**Option A: Update via Helm (Recommended)**

Update `k8s/infra/traefik/values-externalips.yaml`:

```yaml
ingressRoute:
  dashboard:
    enabled: false  # Disable the built-in IngressRoute
```

Then apply the custom IngressRoute manifest (see `traefik-dashboard-ingressroute.yaml`).

**Option B: Apply Custom IngressRoute**

```bash
kubectl apply -f k8s/infra/traefik/traefik-dashboard-ingressroute.yaml
```

## Step 6: Verify Deployment

```bash
# Check OAuth2-Proxy pods
kubectl get pods -n traefik -l app.kubernetes.io/name=oauth2-proxy

# Check OAuth2-Proxy service
kubectl get svc -n traefik | grep oauth2-proxy

# Check logs
kubectl logs -n traefik -l app.kubernetes.io/name=oauth2-proxy --tail=50
```

## Step 7: Test Authentication

1. Open browser to `https://traefik.pane.run`
2. You should see "Sign in with OpenID Connect"
3. Click sign in → Redirects to Zitadel
4. After successful login → Redirects back to Traefik dashboard
5. Dashboard should be visible with authentication

## Troubleshooting

### OAuth2-Proxy shows "Invalid redirect"
- Verify the redirect URL in Zitadel matches exactly: `https://traefik.pane.run/oauth2/callback`
- Check OAuth2-Proxy logs: `kubectl logs -n traefik -l app.kubernetes.io/name=oauth2-proxy`

### Dashboard not loading
- Check if OAuth2-Proxy can reach Traefik:
  ```bash
  kubectl exec -n traefik deployment/oauth2-proxy-traefik -- wget -O- http://traefik.traefik.svc.cluster.local:8080
  ```

### Authentication loop
- Clear browser cookies for `.pane.run` domain
- Verify cookie secret is set correctly in values
- Check that PKCE is enabled in Zitadel application

### Check IngressRoute
```bash
kubectl get ingressroute traefik-dashboard -n traefik -o yaml
```

The IngressRoute should route to `oauth2-proxy-traefik` service, not `api@internal`.

## Architecture Details

### Services
- **oauth2-proxy-traefik** (traefik namespace): OAuth2-Proxy service on port 80
- **traefik** (traefik namespace): Traefik main service with dashboard API on port 8080

### Flow
```
User Browser
    ↓
traefik.pane.run (HTTPS/443)
    ↓
Traefik Ingress Controller
    ↓
OAuth2-Proxy Service (ClusterIP:80 → Pod:4180)
    ↓
[Authentication Check]
    ↓
Traefik Service (ClusterIP:8080 → Dashboard API)
    ↓
Traefik Dashboard
```

## Maintenance

### Update OAuth2-Proxy
```bash
helm upgrade oauth2-proxy-traefik oauth2-proxy/oauth2-proxy \
  -n traefik \
  -f k8s/infra/traefik/oauth2-proxy-values.yaml
```

### Remove Authentication (Rollback)
```bash
# Uninstall OAuth2-Proxy
helm uninstall oauth2-proxy-traefik -n traefik

# Restore original IngressRoute via Helm
# Edit values-externalips.yaml: set ingressRoute.dashboard.enabled: true
helm upgrade traefik traefik/traefik \
  -n traefik \
  -f k8s/infra/traefik/values-externalips.yaml
```

## Security Notes

- Cookie is secured with `httpOnly`, `secure`, and `sameSite=lax` flags
- PKCE flow ensures secure authentication without client secrets
- Session expires after 7 days (configurable in values)
- Token refreshes every hour to maintain valid sessions
