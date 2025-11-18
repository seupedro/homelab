# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **GitOps-based Kubernetes homelab** running on Hetzner Cloud with complete infrastructure-as-code management. The stack uses OpenTofu/Terraform for cloud provisioning, K3s for Kubernetes, ArgoCD for GitOps deployments, and automated TLS via cert-manager + Let's Encrypt.

**Live Infrastructure:**
- **Server**: pane-homelab-k8s (Hetzner CCX13 instance)
- **Location**: Ashburn, Virginia (ash)
- **IPv4**: 178.156.155.139
- **IPv6**: 2a01:4ff:f0:c182::1
- **Domain**: pane.run with wildcard DNS (*.pane.run → server IP)
- **Access**: All services at https://[service].pane.run with auto TLS

## Architecture

### Technology Stack
```
Git Repository (source of truth)
    ↓
OpenTofu (provisions cloud resources)
    ↓
Hetzner Cloud Server + Cloudflare DNS
    ↓
K3s Kubernetes Cluster
    ├─ Traefik (ingress controller)
    ├─ cert-manager (TLS automation)
    ├─ ArgoCD (GitOps controller)
    ├─ Sealed Secrets (encrypt secrets in Git)
    ├─ CloudNativePG (PostgreSQL operator)
    └─ Redis Operator (caching)
    ↓
Applications (auto-deployed from Git)
```

### Key Concepts
- **Everything in Git**: Infrastructure code and Kubernetes manifests are version controlled
- **GitOps**: ArgoCD watches Git and auto-syncs changes to cluster (no manual kubectl apply)
- **Auto TLS**: Any service with an Ingress gets automatic Let's Encrypt certificate via cert-manager
- **Sealed Secrets**: Secrets are encrypted in Git and decrypted in-cluster only

## Repository Structure

```
/
├── main.tf                    # OpenTofu: server + DNS provisioning
├── variables.tf               # Input variables (server type, location, etc.)
├── outputs.tf                 # Exposed values (IPs, URLs)
├── cloud-init.yaml            # Server bootstrap (K3s installation)
├── configure-kubectl.sh       # Configure local kubectl access
├── terraform.tfvars           # Credentials (NEVER COMMIT - gitignored)
├── terraform.tfvars.example   # Credential template
│
├── argocd-operator/           # ArgoCD deployment manifests
│   ├── subscription.yaml      # OLM subscription (ArgoCD operator install)
│   ├── argocd-instance.yaml   # ArgoCD server configuration
│   ├── letsencrypt-issuer.yaml # cert-manager ClusterIssuer
│   └── cert-manager/
│       └── cert-manager.yaml  # cert-manager installation
│
└── kubernetes/                # K8s manifests (to be recreated)
    ├── infrastructure/        # Core components (sealed-secrets, traefik, etc.)
    └── applications/          # User applications
```

## Critical Files

### main.tf
Provisions infrastructure via OpenTofu:
- `hcloud_server.main` - Creates Ubuntu 24.04 server with K3s (via cloud-init.yaml)
- `cloudflare_dns_record.wildcard_a` - A record: *.pane.run → server IPv4
- `cloudflare_dns_record.wildcard_aaaa` - AAAA record: *.pane.run → server IPv6

**Providers:**
- Hetzner Cloud (`hcloud_token` in terraform.tfvars)
- Cloudflare (`cloudflare_api_token`, `cloudflare_zone_id` in terraform.tfvars)

### cloud-init.yaml
First-boot script that:
1. Installs system packages (curl, wget, git, vim, etc.)
2. Configures UFW firewall (ports 22, 80, 443, 6443)
3. Installs K3s from https://get.k3s.io
4. Waits for K3s readiness
5. Sets up kubeconfig at /root/.kube/config

### argocd-operator/argocd-instance.yaml
Defines ArgoCD deployment:
- `spec.server.host: argocd.pane.run` - External hostname
- `spec.server.ingress.enabled: true` - Uses Traefik ingress
- `spec.server.ingress.annotations` - Includes cert-manager issuer annotation
- `spec.server.insecure: true` - Traefik handles TLS termination

### argocd-operator/letsencrypt-issuer.yaml
ClusterIssuer for cert-manager:
- Uses Let's Encrypt production ACME server
- HTTP-01 challenge via Traefik ingress
- Auto-issues certificates for any Ingress with annotation: `cert-manager.io/cluster-issuer: letsencrypt-prod`

## Essential Commands

### Infrastructure Management (OpenTofu)

```bash
# Initialize providers
tofu init

# Preview infrastructure changes
tofu plan

# Apply infrastructure changes (creates/updates server, DNS)
tofu apply

# Show current infrastructure state
tofu show

# Get specific output value
tofu output ipv4_address

# Destroy all infrastructure (DESTRUCTIVE!)
tofu destroy
```

### Kubernetes Access

```bash
# Configure local kubectl to access cluster
./configure-kubectl.sh

# Verify cluster connection
kubectl cluster-info
kubectl get nodes

# View all pods across namespaces
kubectl get pods -A

# Get ArgoCD admin password
kubectl get secret argocd-cluster -n argocd -o jsonpath='{.data.admin\.password}' | base64 -d
```

### Kubernetes Operations

```bash
# List all ArgoCD instances
kubectl get argocd -A

# Check certificate status
kubectl get certificates -A
kubectl describe certificate -n <namespace> <cert-name>

# View cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Fetch sealed-secrets sealing certificate (needed to encrypt secrets)
kubeseal --fetch-cert -o /tmp/sealing-cert.pem

# Create and seal a secret
kubectl create secret generic mysecret \
  --from-literal=key=value \
  --namespace=mynamespace \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml
```

### Server Access

```bash
# SSH to server (update IP from tofu output ipv4_address)
ssh root@178.156.155.139

# Check K3s status on server
systemctl status k3s
journalctl -u k3s -f

# Check firewall rules
ufw status
```

## Common Workflows

### Deploy New Application

1. **Create application directory structure:**
   ```bash
   mkdir -p kubernetes/applications/myapp
   ```

2. **Create Deployment manifest** (`kubernetes/applications/myapp/deployment.yaml`)

3. **Create Service manifest** (`kubernetes/applications/myapp/service.yaml`)

4. **Create Ingress with TLS** (`kubernetes/applications/myapp/ingress.yaml`):
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: myapp
     namespace: myapp
     annotations:
       cert-manager.io/cluster-issuer: letsencrypt-prod
   spec:
     ingressClassName: traefik
     tls:
     - secretName: myapp-tls
       hosts:
       - myapp.pane.run
     rules:
     - host: myapp.pane.run
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: myapp
               port:
                 number: 8080
   ```

5. **If secrets needed, create SealedSecret:**
   ```bash
   kubectl create secret generic myapp-secret \
     --from-literal=api_key="secret_value" \
     --namespace=myapp \
     --dry-run=client -o yaml | \
     kubeseal -o yaml > kubernetes/applications/myapp/secret-sealed.yaml
   ```

6. **Commit and push:**
   ```bash
   git add kubernetes/applications/myapp/
   git commit -m "Deploy myapp"
   git push
   ```

7. **ArgoCD auto-detects and deploys within 3 minutes**

8. **Access at https://myapp.pane.run with automatic TLS certificate**

### Update Infrastructure

1. **Modify configuration** (main.tf or terraform.tfvars)

2. **Preview changes:**
   ```bash
   tofu plan
   ```

3. **Apply changes:**
   ```bash
   tofu apply
   ```

4. **If IP changes, reconfigure kubectl:**
   ```bash
   ./configure-kubectl.sh
   ```

### Change Server Size

Edit `terraform.tfvars`:
```hcl
server_type = "ccx21"  # Upgrade from ccx13
```

Apply changes:
```bash
tofu plan
tofu apply  # Server is resized with brief downtime
```

### Add DNS Subdomain

Add to `main.tf`:
```hcl
resource "cloudflare_dns_record" "myapp" {
  zone_id = var.cloudflare_zone_id
  name    = "myapp"
  content = hcloud_server.main.ipv4_address
  type    = "A"
  ttl     = 1
  proxied = false
  comment = "DNS for myapp.pane.run"
}
```

Apply:
```bash
tofu apply
```

## Key Configuration Patterns

### ArgoCD Application Manifest
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/username/homelab.git
    targetRevision: HEAD
    path: kubernetes/applications/myapp
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### ApplicationSet for Auto-Discovery
Creates an Application for each subdirectory in a path:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: applications
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/username/homelab.git
      revision: HEAD
      directories:
      - path: kubernetes/applications/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/username/homelab.git
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

## Security Guidelines

### Secrets Management
- **NEVER commit unencrypted secrets to Git**
- Use SealedSecrets for all credentials (DB passwords, API tokens, SSH keys)
- Backup sealed-secrets sealing key offline:
  ```bash
  kubectl get secret -n sealed-secrets sealed-secrets-key -o yaml > sealed-secrets-backup.yaml
  # Store safely - needed for disaster recovery
  ```

### Files to Keep Out of Git
Already in `.gitignore`:
- `terraform.tfvars` - Contains API tokens
- `terraform.tfstate*` - Contains sensitive infrastructure state
- `.terraform/` - Provider binaries
- `terraform/kubeconfig` - Cluster credentials

## Environment Setup

### Required Credentials (terraform.tfvars)
```hcl
hcloud_token = "xxx"              # From Hetzner Cloud Console
cloudflare_api_token = "xxx"      # From Cloudflare Dashboard
cloudflare_zone_id = "xxx"        # Zone ID for pane.run domain
server_name = "pane-homelab-k8s"
server_type = "ccx13"
location = "ash"
```

### Initial Setup Steps
1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Add Hetzner and Cloudflare credentials
3. Run `tofu init` to download providers
4. Run `tofu apply` to create infrastructure (6-8 minutes)
5. Run `./configure-kubectl.sh` to configure local kubectl
6. Apply ArgoCD manifests: `kubectl apply -f argocd-operator/`
7. Access ArgoCD at https://argocd.pane.run

## Integration Points

### ArgoCD Operator
- Installed via OLM (Operator Lifecycle Manager)
- Subscription watches `alpha` channel from custom catalog source
- Manages ArgoCD instance lifecycle (upgrades, config changes)

### cert-manager
- Watches Ingress resources with annotation `cert-manager.io/cluster-issuer: letsencrypt-prod`
- Creates Certificate resources automatically
- Issues certificates via Let's Encrypt HTTP-01 challenge
- Stores certificates in TLS secrets referenced by Ingress

### Traefik
- Default K3s ingress controller
- Handles TLS termination (uses cert-manager issued certificates)
- Configured via IngressClass: `traefik`
- Supports automatic HTTP→HTTPS redirect via annotations

### Cloudflare DNS
- Managed via OpenTofu cloudflare provider
- Wildcard records (`*.pane.run`) point to server IP
- DNS-only mode (proxied: false) - not using Cloudflare proxy
- Updates automatically when server IP changes

## Known Limitations

- **Single node cluster**: No HA, suitable for homelab/testing only
- **No persistent storage class configured**: Apps needing PVs must define their own
- **Sealed Secrets sealing key**: If lost, all secrets must be re-encrypted
- **Server recreation**: Destroys all cluster data (backup important data to external storage)

## Debugging Tips

### Infrastructure Issues
```bash
# Check OpenTofu state
tofu show

# Verify DNS propagation
dig +short argocd.pane.run

# SSH to server and check K3s
ssh root@$(tofu output -raw ipv4_address)
systemctl status k3s
kubectl get nodes
```

### Certificate Issues
```bash
# Check certificate status
kubectl get certificate -n <namespace>
kubectl describe certificate <cert-name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

### ArgoCD Issues
```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# View ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Check Applications sync status
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
```

### Network/Ingress Issues
```bash
# Check Traefik pods
kubectl get pods -n kube-system | grep traefik

# Check Ingress resources
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>

# Check service endpoints
kubectl get endpoints -n <namespace>
```

## ArgoCD Credentials

Initial admin password is stored in cluster:
```bash
kubectl get secret argocd-cluster -n argocd -o jsonpath='{.data.admin\.password}' | base64 -d
```

Access at: https://argocd.pane.run
- Username: `admin`
- Password: (from command above)
