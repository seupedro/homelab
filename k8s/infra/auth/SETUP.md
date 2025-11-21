# Complete Setup Guide: Zitadel + OAuth2-Proxy + Traefik Forward Auth

This guide walks you through completing the authentication setup for your homelab.

## Current Status

✅ Zitadel is deployed and running at: **https://zitadel.pane.run**
✅ PostgreSQL database configured
✅ OAuth2-Proxy manifests created
⏳ **Next:** Create OAuth2 application and deploy OAuth2-Proxy

---

## Step 1: Create OAuth2 Application in Zitadel

1. **Access Zitadel UI**:
   ```
   https://zitadel.pane.run
   ```

2. **Login with admin credentials**:
   - Username: `admin`
   - Password: `5mJd7BrH&HYAiBd9D3pD1QZ^`

3. **Create a new Project**:
   - Click on **"Organization"** in the top menu
   - Navigate to **"Projects"** in the left sidebar
   - Click **"+ New"** button
   - Enter project name: `Authentication Proxy`
   - Click **"Continue"**

4. **Create an Application**:
   - In the newly created project, click **"New Application"**
   - Enter application name: `OAuth2-Proxy`
   - Select application type: **"WEB"**
   - Click **"Continue"**

5. **Configure Authentication Method**:
   - Select: **"PKCE"** (recommended)
   - Click **"Continue"**

6. **Configure Redirect URIs**:
   Add the following redirect URIs:
   ```
   https://auth.pane.run/oauth2/callback
   ```

   Add post-logout redirect URI:
   ```
   https://zitadel.pane.run
   ```

   Click **"Continue"**

7. **Review and Create**:
   - Review the settings
   - Click **"Create"**

8. **Save Credentials**:
   After creation, you'll see:
   - **Client ID**: `<copy this value>`
   - **Client Secret**: `<copy this value>`

   ⚠️ **IMPORTANT**: Save these credentials - you'll need them in the next step!

---

## Step 2: Update OAuth2-Proxy Secrets

1. **Edit the secrets file**:
   ```bash
   nano k8s/auth/secrets.yaml
   ```

2. **Replace the placeholders**:
   - Replace `PLACEHOLDER_CLIENT_ID` with your actual Client ID
   - Replace `PLACEHOLDER_CLIENT_SECRET` with your actual Client Secret
   - Save the file (Ctrl+O, Enter, Ctrl+X)

3. **Apply the secrets**:
   ```bash
   kubectl apply -f k8s/auth/secrets.yaml
   ```

   Verify:
   ```bash
   kubectl get secret -n auth
   ```

---

## Step 3: Deploy OAuth2-Proxy

1. **Add OAuth2-Proxy Helm repository**:
   ```bash
   helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
   helm repo update
   ```

2. **Install OAuth2-Proxy**:
   ```bash
   helm install oauth2-proxy oauth2-proxy/oauth2-proxy \
     -n auth \
     -f k8s/auth/values.yaml
   ```

3. **Apply certificate and IngressRoute**:
   ```bash
   kubectl apply -f k8s/auth/certificate.yaml
   kubectl apply -f k8s/auth/ingressroute.yaml
   ```

4. **Wait for certificate to be issued**:
   ```bash
   kubectl get certificate -n auth -w
   ```
   Wait until `READY` shows `True` (press Ctrl+C to stop watching)

5. **Verify OAuth2-Proxy is running**:
   ```bash
   kubectl get pods -n auth
   ```

   Test the health endpoint:
   ```bash
   curl -I https://auth.pane.run/ping
   ```
   Should return: `HTTP/2 200`

---

## Step 4: Apply ForwardAuth Middleware

1. **Apply the middleware**:
   ```bash
   kubectl apply -f k8s/auth/middleware-forwardauth.yaml
   ```

2. **Verify middleware is created**:
   ```bash
   kubectl get middleware -n auth
   ```

---

## Step 5: Protect whoami with Authentication

1. **Update whoami IngressRoute** to add authentication:
   ```bash
   # Backup the original
   cp k8s/whoami/ingressroute.yaml k8s/whoami/ingressroute.yaml.backup

   # Edit the IngressRoute
   nano k8s/whoami/ingressroute.yaml
   ```

2. **Add the middleware** to the routes section:
   ```yaml
   apiVersion: traefik.io/v1alpha1
   kind: IngressRoute
   metadata:
     name: whoami
     namespace: whoami
     labels:
       app: whoami
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

3. **Apply the updated IngressRoute**:
   ```bash
   kubectl apply -f k8s/whoami/ingressroute.yaml
   ```

---

## Step 6: Test the Authentication Flow

1. **Open your browser** and navigate to:
   ```
   https://whoami.pane.run
   ```

2. **Expected behavior**:
   - You should be redirected to Zitadel login page
   - After logging in with admin credentials, you'll be redirected back to whoami
   - The whoami page will show your authentication headers

3. **Verify authentication headers**:
   Look for headers like:
   - `X-Auth-Request-User: admin`
   - `X-Auth-Request-Email: admin@...`

4. **Test health endpoints**:
   ```bash
   # Zitadel health
   curl https://zitadel.pane.run/debug/healthz

   # OAuth2-Proxy health
   curl https://auth.pane.run/ping
   ```

---

## Troubleshooting

### OAuth2-Proxy won't start
```bash
# Check logs
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy

# Common issues:
# - Missing or incorrect client credentials in secrets
# - OIDC issuer URL not accessible
```

### Redirect loop or 401 errors
```bash
# Check middleware is applied
kubectl describe ingressroute whoami -n whoami

# Check OAuth2-Proxy logs
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy --tail=50
```

### Certificate not ready
```bash
# Check certificate status
kubectl describe certificate -n auth

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50
```

---

## Next Steps

Once authentication is working on whoami, you can protect other services by:

1. Adding the same middleware to their IngressRoutes:
   ```yaml
   middlewares:
     - name: oauth2-forward-auth
       namespace: auth
   ```

2. Adding their callback URLs to the Zitadel application redirect URIs

3. Testing the authentication flow

---

## Summary

You now have:
- ✅ Zitadel identity provider at https://zitadel.pane.run
- ✅ OAuth2-Proxy forward auth service at https://auth.pane.run
- ✅ Protected whoami application at https://whoami.pane.run
- ✅ Traefik middleware for easy authentication on any service

**Admin Credentials:**
- Zitadel URL: https://zitadel.pane.run
- Username: `admin`
- Password: `5mJd7BrH&HYAiBd9D3pD1QZ^`
