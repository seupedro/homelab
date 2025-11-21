# Zitadel + OAuth2-Proxy + Traefik Forward Auth Deployment Summary

## ✅ What Has Been Deployed

### 1. PostgreSQL Database Setup
- **Database**: `zitadel` created in postgresql-16 cluster
- **Users**:
  - `zitadel_admin` (for schema migrations)
  - `zitadel_user` (for runtime operations)
- **Permissions**: Properly configured with CREATEDB, CREATEROLE

### 2. Zitadel Identity Provider
- **Namespace**: `zitadel`
- **URL**: https://zitadel.pane.run
- **Admin Credentials**:
  - Username: `admin`
  - Password: `5mJd7BrH&HYAiBd9D3pD1QZ^`
- **Status**: ✅ Running and accessible
- **Health Check**: https://zitadel.pane.run/debug/healthz

### 3. OAuth2-Proxy Infrastructure
- **Namespace**: `auth` (created)
- **Manifests**: All created and ready to deploy
  - Helm values configuration
  - Secrets template (needs OAuth2 app credentials)
  - TLS certificate configuration (auth.pane.run)
  - IngressRoute configuration
  - ForwardAuth middleware

### 4. Updated whoami Configuration
- **Template**: Created at `k8s/whoami/ingressroute-with-auth.yaml`
- **Middleware**: Configured to use OAuth2 forward auth

### 5. Deployment Scripts
- **k8s/auth/deploy.sh**: Automated OAuth2-Proxy deployment
- **k8s/auth/test-auth.sh**: End-to-end authentication testing
- **k8s/auth/SETUP.md**: Comprehensive step-by-step guide

---

## ⏳ What Needs to Be Done (Manual Steps)

### Step 1: Create OAuth2 Application in Zitadel

1. **Access Zitadel**:
   ```
   https://zitadel.pane.run
   ```
   Login: `admin` / `5mJd7BrH&HYAiBd9D3pD1QZ^`

2. **Create Project and Application**:
   - Follow the detailed instructions in `k8s/auth/SETUP.md`
   - You'll receive a Client ID and Client Secret

### Step 2: Update OAuth2-Proxy Secrets

1. **Edit secrets**:
   ```bash
   nano k8s/auth/secrets.yaml
   ```

2. **Replace placeholders**:
   - `PLACEHOLDER_CLIENT_ID` → Your actual Client ID
   - `PLACEHOLDER_CLIENT_SECRET` → Your actual Client Secret

### Step 3: Deploy OAuth2-Proxy

Run the automated deployment script:
```bash
./k8s/auth/deploy.sh
```

This will:
- Apply secrets
- Install OAuth2-Proxy via Helm
- Apply certificate and IngressRoute
- Apply ForwardAuth middleware
- Wait for everything to be ready

### Step 4: Protect whoami Application

Apply the updated IngressRoute:
```bash
kubectl apply -f k8s/whoami/ingressroute-with-auth.yaml
```

### Step 5: Test the Setup

Run the test script:
```bash
./k8s/auth/test-auth.sh
```

Or test manually:
```bash
# Should return 200
curl https://zitadel.pane.run/debug/healthz

# Should return 200
curl https://auth.pane.run/ping

# Should redirect to Zitadel login (302 or 401)
curl -I https://whoami.pane.run
```

### Step 6: Browser Test

1. Open browser and navigate to: **https://whoami.pane.run**
2. You should be redirected to Zitadel login
3. Login with admin credentials
4. You should be redirected back to whoami
5. Verify authentication headers are present

---

## 📁 File Structure

```
k8s/
├── zitadel/
│   ├── namespace.yaml                 # Zitadel namespace
│   ├── secrets.yaml                   # Masterkey and DB credentials
│   ├── values.yaml                    # Helm values
│   ├── certificate.yaml               # TLS certificate
│   └── ingressroute.yaml              # Traefik routing
│
├── auth/
│   ├── SETUP.md                       # Comprehensive setup guide
│   ├── README.md                      # Quick reference
│   ├── namespace.yaml                 # Auth namespace
│   ├── secrets.yaml                   # OAuth2-Proxy credentials (TO UPDATE)
│   ├── values.yaml                    # OAuth2-Proxy Helm values
│   ├── certificate.yaml               # TLS certificate for auth.pane.run
│   ├── ingressroute.yaml              # Traefik routing
│   ├── middleware-forwardauth.yaml    # ForwardAuth middleware
│   ├── deploy.sh                      # Automated deployment script
│   ├── test-auth.sh                   # Testing script
│   └── create-zitadel-app.sh          # API-based app creation (experimental)
│
└── whoami/
    ├── ingressroute.yaml              # Original (no auth)
    └── ingressroute-with-auth.yaml    # With authentication middleware
```

---

## 🔐 Security Credentials

### Zitadel Admin
- **URL**: https://zitadel.pane.run
- **Username**: `admin`
- **Password**: `5mJd7BrH&HYAiBd9D3pD1QZ^`

### PostgreSQL zitadel Database
- **Host**: postgresql-16-rw.postgres.svc.cluster.local:5432
- **Database**: `zitadel`
- **Admin User**: `zitadel_admin` / `lAa0cnb0PkUz7TcIKL0x62uAoZEDQxTb`
- **Runtime User**: `zitadel_user` / `04EEvVRHy6tDZqKDTNi8w4oGRmANuZAo`

### OAuth2-Proxy
- **Cookie Secret**: `qMfIvDhNljZygy+knjIpdoldyJbCUCcZuVOcnkgIvwc=`
- **Client ID**: (from Zitadel app - to be created)
- **Client Secret**: (from Zitadel app - to be created)

---

## 🔗 Access URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Zitadel | https://zitadel.pane.run | Identity provider & admin UI |
| Zitadel Health | https://zitadel.pane.run/debug/healthz | Health check |
| OAuth2-Proxy | https://auth.pane.run | Forward authentication service |
| OAuth2 Health | https://auth.pane.run/ping | Health check |
| Whoami (protected) | https://whoami.pane.run | Test application |

---

## 🚀 Quick Start

To complete the deployment:

```bash
# 1. Create OAuth2 app in Zitadel UI (see k8s/auth/SETUP.md)

# 2. Update secrets with credentials from Zitadel
nano k8s/auth/secrets.yaml

# 3. Deploy OAuth2-Proxy
./k8s/auth/deploy.sh

# 4. Protect whoami
kubectl apply -f k8s/whoami/ingressroute-with-auth.yaml

# 5. Test
./k8s/auth/test-auth.sh

# 6. Open browser
open https://whoami.pane.run
```

---

## 📚 Documentation

- **Complete Setup Guide**: `k8s/auth/SETUP.md`
- **Quick Reference**: `k8s/auth/README.md`
- **Zitadel Documentation**: https://zitadel.com/docs
- **OAuth2-Proxy Documentation**: https://oauth2-proxy.github.io/oauth2-proxy/

---

## 🔍 Troubleshooting

### Common Issues

1. **OAuth2-Proxy won't start**
   - Check if secrets are updated: `grep PLACEHOLDER k8s/auth/secrets.yaml`
   - Check logs: `kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy`

2. **Certificate not ready**
   - Check status: `kubectl get certificate -n auth`
   - Check cert-manager: `kubectl logs -n cert-manager -l app=cert-manager`

3. **Redirect loops**
   - Verify middleware is applied: `kubectl describe ingressroute whoami -n whoami`
   - Check OAuth2-Proxy logs

4. **401/403 errors**
   - Verify Zitadel app has correct redirect URIs
   - Check OAuth2-Proxy configuration in values.yaml

### Useful Commands

```bash
# Check all pods
kubectl get pods -n zitadel,auth,whoami

# Check certificates
kubectl get certificates -A

# Check middleware
kubectl get middleware -n auth

# Check IngressRoutes
kubectl get ingressroute -A

# View logs
kubectl logs -n zitadel -l app.kubernetes.io/name=zitadel --tail=50
kubectl logs -n auth -l app.kubernetes.io/name=oauth2-proxy --tail=50
```

---

## ✨ Next Steps

After successful deployment:

1. **Create additional users** in Zitadel
2. **Protect other services** by adding the same middleware to their IngressRoutes
3. **Configure user registration** settings in Zitadel
4. **Set up email notifications** (optional)
5. **Implement fine-grained authorization** using Zitadel roles and groups

---

## 📝 Notes

- All passwords and secrets are stored in Kubernetes secrets
- TLS certificates are automatically managed by cert-manager
- Zitadel stores all data in the PostgreSQL database
- OAuth2-Proxy is stateless and can be scaled horizontally (requires Redis for sessions)
- The middleware can be reused across multiple applications

---

**Deployment Date**: 2025-11-19
**Deployed By**: Claude Code
