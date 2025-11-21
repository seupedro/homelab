# SearXNG Deployment - Remaining Steps

## Current Status

✅ SearXNG application deployed and running
✅ Certificate issued successfully
✅ Secrets generated
⏳ OAuth2-Proxy setup pending (requires Zitadel application)
⏳ IngressRoute pending

## Next Steps

### Step 1: Create Zitadel Application

1. **Access Zitadel Console**
   ```bash
   # Open in browser
   https://zitadel.pane.run
   ```

2. **Create New Application**
   - Navigate to: Projects → (Your Project) → Applications
   - Click "New Application"
   - Configuration:
     - **Name**: `SearXNG`
     - **Type**: `Web`
     - **Authentication Method**: `PKCE`

3. **Configure Application**
   - **Redirect URIs**:
     ```
     https://searxng.pane.run/oauth2/callback
     ```
   - **Post Logout Redirect URIs**:
     ```
     https://searxng.pane.run
     ```
   - **Allowed Scopes**:
     - `openid`
     - `profile`
     - `email`

4. **Save and Copy Client ID**
   - After saving, you'll see the Client ID
   - Copy it for the next step
   - Example format: `347560624261169352`

### Step 2: Update OAuth2-Proxy Configuration

Update the client ID in the values file:

```bash
# Edit the file
nano k8s/apps/searxng/oauth2-proxy-values.yaml

# Replace this line:
#   clientID: "REPLACE_WITH_ZITADEL_CLIENT_ID"
# With your actual Client ID from Zitadel:
#   clientID: "YOUR_CLIENT_ID_HERE"
```

Or use sed:
```bash
sed -i 's/REPLACE_WITH_ZITADEL_CLIENT_ID/YOUR_CLIENT_ID_HERE/g' k8s/apps/searxng/oauth2-proxy-values.yaml
```

### Step 3: Add OAuth2-Proxy Helm Repository

```bash
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update
```

### Step 4: Deploy OAuth2-Proxy

```bash
helm install oauth2-proxy-searxng oauth2-proxy/oauth2-proxy \
  -n searxng \
  -f k8s/apps/searxng/oauth2-proxy-values.yaml \
  --wait
```

Expected output:
```
NAME: oauth2-proxy-searxng
LAST DEPLOYED: [timestamp]
NAMESPACE: searxng
STATUS: deployed
```

Verify deployment:
```bash
kubectl get pods -n searxng
```

You should see:
```
NAME                                    READY   STATUS    RESTARTS   AGE
searxng-67cd5746d-tphhz                 1/1     Running   0          2m
oauth2-proxy-searxng-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
```

### Step 5: Apply IngressRoute

```bash
kubectl apply -f k8s/apps/searxng/ingressroute.yaml
```

Verify:
```bash
kubectl get ingressroute -n searxng
```

### Step 6: Test Authentication Flow

1. **Open in Browser**
   ```
   https://searxng.pane.run
   ```

2. **Expected Flow**:
   - You should see: "Sign in with OpenID Connect" page
   - Click "Sign in" button
   - Redirects to Zitadel login page
   - Enter your credentials
   - After successful login → Redirects back to SearXNG
   - You should see the SearXNG search interface

3. **Verify with curl**:
   ```bash
   # Should return 403 or redirect (not 401)
   curl -I https://searxng.pane.run

   # Should show sign-in page HTML
   curl -s https://searxng.pane.run | head -20
   ```

## Troubleshooting

### OAuth2-Proxy Not Starting

Check logs:
```bash
kubectl logs -n searxng -l app.kubernetes.io/name=oauth2-proxy --tail=100
```

Common issues:
- Invalid client ID
- Incorrect OIDC issuer URL
- Missing cookie secret

### "Invalid redirect URI" Error

**Cause**: Redirect URL not registered in Zitadel

**Solution**: Verify in Zitadel that `https://searxng.pane.run/oauth2/callback` is in the Redirect URIs list

### 404 After Login

**Cause**: OAuth2-Proxy upstream not configured correctly

**Solution**: Check logs:
```bash
kubectl logs -n searxng -l app.kubernetes.io/name=oauth2-proxy | grep "mapping path"
```

Should show:
```
mapping path "/" => upstream "http://searxng.searxng.svc.cluster.local:8080"
```

### Certificate Issues

Check certificate status:
```bash
kubectl describe certificate searxng-pane-run-tls -n searxng
```

Check cert-manager logs:
```bash
kubectl logs -n cert-manager -l app=cert-manager --tail=50
```

## Quick Commands Reference

```bash
# Check all resources in searxng namespace
kubectl get all -n searxng

# View SearXNG logs
kubectl logs -n searxng -l app=searxng --tail=100 -f

# View OAuth2-Proxy logs
kubectl logs -n searxng -l app.kubernetes.io/name=oauth2-proxy --tail=100 -f

# Restart SearXNG
kubectl rollout restart deployment/searxng -n searxng

# Restart OAuth2-Proxy
kubectl rollout restart deployment/oauth2-proxy-searxng -n searxng

# Delete and redeploy OAuth2-Proxy (if needed)
helm uninstall oauth2-proxy-searxng -n searxng
helm install oauth2-proxy-searxng oauth2-proxy/oauth2-proxy \
  -n searxng \
  -f k8s/apps/searxng/oauth2-proxy-values.yaml \
  --wait
```

## Post-Deployment Configuration

Once deployed, you can customize SearXNG by editing the ConfigMap:

```bash
kubectl edit configmap searxng-config -n searxng
```

After editing, restart the deployment:
```bash
kubectl rollout restart deployment/searxng -n searxng
```

## Success Criteria

✅ SearXNG pod running (1/1 Ready)
✅ OAuth2-Proxy pod running (1/1 Ready)
✅ Certificate ready (READY=True)
✅ IngressRoute created
✅ Can access https://searxng.pane.run
✅ Sign-in redirects to Zitadel
✅ After login, can see SearXNG interface
✅ Search functionality works

---

**Need help?** Check the full README.md in this directory or the homelab documentation at `/home/seupedro/homelab/docs/`
