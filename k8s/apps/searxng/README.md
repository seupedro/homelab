# SearXNG Deployment

Privacy-respecting metasearch engine at https://searxng.pane.run

## Overview

- **Version**: 2025.9.29-77fd3ee53
- **Image**: `searxng/searxng:2025.9.29-77fd3ee53`
- **Port**: 8080
- **Authentication**: OAuth2-Proxy with Zitadel (OIDC)
- **Rate Limiting**: Disabled (no Redis integration)

## Prerequisites

1. Kubernetes cluster running
2. Helm installed
3. OAuth2-Proxy Helm chart repository added:
   ```bash
   helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
   helm repo update
   ```

## Deployment Steps

### 1. Generate Cookie Secret

Generate a secure random cookie secret for OAuth2-Proxy:

```bash
openssl rand -base64 32
```

Update the `cookieSecret` in `oauth2-proxy-values.yaml` with the generated value.

### 2. Update Secret Key

Generate a secure random secret key for SearXNG:

```bash
openssl rand -hex 32
```

Update the `secret_key` in `secret.yaml` with the generated value.

### 3. Create Zitadel Application

1. Log in to Zitadel at https://zitadel.pane.run
2. Go to Projects → (Your Project) → Applications
3. Click "New Application"
4. Configure:
   - **Name**: SearXNG
   - **Type**: Web
   - **Authentication Method**: PKCE
5. Add Redirect URIs:
   - `https://searxng.pane.run/oauth2/callback`
6. Add Post Logout Redirect URIs:
   - `https://searxng.pane.run`
7. Allowed Scopes: `openid`, `profile`, `email`
8. Save and copy the **Client ID**

### 4. Update OAuth2-Proxy Configuration

Update `oauth2-proxy-values.yaml`:
- Replace `REPLACE_WITH_ZITADEL_CLIENT_ID` with the Client ID from Zitadel
- Replace `REPLACE_WITH_GENERATED_COOKIE_SECRET` with the cookie secret from step 1

### 5. Deploy SearXNG

Apply the SearXNG manifests:

```bash
# Apply base manifests
kubectl apply -f namespace.yaml
kubectl apply -f secret.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f certificate.yaml

# Wait for certificate to be ready
kubectl wait --for=condition=Ready certificate/searxng-pane-run-tls -n searxng --timeout=300s
```

### 6. Deploy OAuth2-Proxy

Deploy OAuth2-Proxy using Helm:

```bash
helm install oauth2-proxy-searxng oauth2-proxy/oauth2-proxy \
  -n searxng \
  -f oauth2-proxy-values.yaml \
  --wait
```

### 7. Apply IngressRoute

Apply the Traefik IngressRoute:

```bash
kubectl apply -f ingressroute.yaml
```

### 8. Verify Deployment

Check that all pods are running:

```bash
kubectl get pods -n searxng
```

Expected output:
```
NAME                                    READY   STATUS    RESTARTS   AGE
searxng-xxxxxxxxxx-xxxxx                1/1     Running   0          1m
oauth2-proxy-searxng-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

Check the IngressRoute:

```bash
kubectl get ingressroute -n searxng
```

### 9. Test Authentication

Open https://searxng.pane.run in your browser:

1. You should see "Sign in with OpenID Connect" page
2. Click "Sign in" → Redirects to Zitadel
3. Log in with your Zitadel credentials
4. After successful login → Redirects back to SearXNG
5. You should see the SearXNG search interface

## Management

### View Logs

```bash
# SearXNG logs
kubectl logs -n searxng -l app=searxng --tail=100 -f

# OAuth2-Proxy logs
kubectl logs -n searxng -l app.kubernetes.io/name=oauth2-proxy --tail=100 -f
```

### Check Health

```bash
# SearXNG health
kubectl exec -n searxng deployment/searxng -- wget -q -O- http://localhost:8080/healthz

# OAuth2-Proxy health
kubectl exec -n searxng deployment/oauth2-proxy-searxng -- wget -q -O- http://localhost:4180/ping
```

### Update SearXNG

To update to a newer version:

1. Update the image tag in `deployment.yaml`
2. Apply the changes:
   ```bash
   kubectl apply -f deployment.yaml
   ```

### Update OAuth2-Proxy

To update OAuth2-Proxy configuration:

```bash
helm upgrade oauth2-proxy-searxng oauth2-proxy/oauth2-proxy \
  -n searxng \
  -f oauth2-proxy-values.yaml \
  --wait
```

## Troubleshooting

### Issue: "Invalid redirect URI" from Zitadel

**Solution**: Verify the redirect URI in Zitadel matches exactly:
- `https://searxng.pane.run/oauth2/callback`

### Issue: 404 after successful login

**Solution**: Check OAuth2-Proxy logs for upstream configuration:

```bash
kubectl logs -n searxng -l app.kubernetes.io/name=oauth2-proxy | grep "mapping path"
```

Should show: `mapping path "/" => upstream "http://searxng.searxng.svc.cluster.local:8080"`

### Issue: Certificate not ready

**Solution**: Check cert-manager logs:

```bash
kubectl logs -n cert-manager -l app=cert-manager --tail=50
kubectl describe certificate searxng-pane-run-tls -n searxng
```

### Issue: OAuth2-Proxy not starting

**Solution**: Check for configuration errors:

```bash
kubectl logs -n searxng -l app.kubernetes.io/name=oauth2-proxy
kubectl describe pod -n searxng -l app.kubernetes.io/name=oauth2-proxy
```

## Architecture

```
Browser Request (https://searxng.pane.run)
    ↓
Traefik Ingress (port 443)
    ↓
OAuth2-Proxy (port 4180)
    ├─ Not authenticated? → Redirect to Zitadel login
    │                       ↓
    │                    User logs in at Zitadel
    │                       ↓
    │                    Redirect back to OAuth2-Proxy callback
    │                       ↓
    └─ Authenticated! → Proxy request to SearXNG backend
                            ↓
                        SearXNG (port 8080)
                            ↓
                        Return search results
```

## Configuration

### SearXNG Settings

Edit `configmap.yaml` to modify SearXNG settings:
- Search engines
- Safe search level
- Autocomplete
- Theme
- Default language

After changes, restart SearXNG:

```bash
kubectl rollout restart deployment/searxng -n searxng
```

### OAuth2-Proxy Settings

Edit `oauth2-proxy-values.yaml` to modify authentication settings:
- Cookie expiration
- Session refresh interval
- Allowed email domains
- Scopes

After changes, upgrade the Helm release:

```bash
helm upgrade oauth2-proxy-searxng oauth2-proxy/oauth2-proxy \
  -n searxng \
  -f oauth2-proxy-values.yaml \
  --wait
```

## Uninstallation

To remove SearXNG:

```bash
# Remove Helm release
helm uninstall oauth2-proxy-searxng -n searxng

# Remove Kubernetes resources
kubectl delete -f ingressroute.yaml
kubectl delete -f certificate.yaml
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
kubectl delete -f configmap.yaml
kubectl delete -f secret.yaml
kubectl delete -f namespace.yaml
```

Don't forget to remove the application from Zitadel as well.

## Resources

- **SearXNG Documentation**: https://docs.searxng.org/
- **OAuth2-Proxy Documentation**: https://oauth2-proxy.github.io/oauth2-proxy/
- **Zitadel Documentation**: https://zitadel.com/docs
- **Homelab Documentation**: `/home/seupedro/homelab/docs/oauth2-proxy-reverse-proxy-mode.md`
