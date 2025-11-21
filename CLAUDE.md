# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a homelab infrastructure repository managing a single-node Kubernetes cluster running on Hetzner Cloud with Talos Linux. The infrastructure uses OpenTofu for cloud provisioning, Talos for OS management, and Kubernetes for application orchestration.

## IMPORTANT

Prioritize the agent kubernetes-architect and skill kubernetes-operations when managing this cluster.

## Infrastructure Stack

- **Cloud Provider**: Hetzner Cloud (via OpenTofu/Terraform)
- **DNS**: Cloudflare (wildcard DNS for *.pane.run)
- **OS**: Talos Linux v1.11.5 (immutable Kubernetes OS)
- **Cluster**: Single-node Kubernetes (v1.34.1)
- **Ingress**: Traefik v3.6.0 (with Let's Encrypt TLS, using externalIPs for external access)
- **Authentication**: OAuth2-Proxy v7.13.0 with Zitadel v4.2.0 OIDC provider
- **Database**: CloudNative-PG operator v1.27.1 (PostgreSQL 16 and 18)
- **Cache**: Redis v8.2.3 (deployed in storage namespace, used by Zitadel)
- **Storage**: local-path-provisioner
- **Cert Manager**: cert-manager v1.19.1
- **Monitoring**: Prometheus + Grafana + Loki stack (kube-prometheus-stack v0.79.2)
- **Metrics**: metrics-server (Kubernetes metrics aggregator)

## Common Commands

### Infrastructure Management (OpenTofu/Terraform)

```bash
# Navigate to terraform directory
cd terraform/

# Initialize and apply infrastructure
terraform init
terraform plan
terraform apply

# View outputs (server IPs, DNS records)
terraform output

# Variables are in terraform.tfvars (not committed)
# Example template: terraform.tfvars.example
```

### Talos Cluster Management

```bash
# Talos config location
export TALOSCONFIG=talos/talosconfig

# Cluster access
talosctl health --nodes talos.pane.run
talosctl dashboard --nodes talos.pane.run
talosctl version --nodes talos.pane.run

# Generate new cluster config (when needed)
talosctl gen config <cluster-name> https://<endpoint>:6443 \
  --with-docs=false --with-examples=false --output-dir talos

# Kubeconfig location
export KUBECONFIG=talos/kubeconfig
```

### Kubernetes Operations

```bash
# Current context: admin@pane-homelab
kubectl get nodes
kubectl get namespaces

# View all resources across namespaces
kubectl get all -A

# Check Helm releases
helm list -A

# Get complete cluster snapshot (comprehensive view)
./scripts/cluster-snapshot.sh

# Save snapshot to file
./scripts/cluster-snapshot.sh --save

# Install GNU Parallel for 2-3x faster performance
./scripts/install-parallel.sh
```

### Application Deployment

**Deploy new application using the automation script:**

```bash
./scripts/deploy-app.sh \
  --name myapp \
  --subdomain myapp \
  --image nginx:latest \
  --port 80 \
  --replicas 2
```

This script:
1. Generates manifests from templates in `k8s/templates/`
2. Saves them to `k8s/apps/<app-name>/`
3. Applies manifests to cluster
4. Runs health checks with automatic rollback on failure

**Deploy manually:**

```bash
kubectl apply -f k8s/apps/<app-name>/
```

### Health Checks

```bash
# Standalone health check with retries
./scripts/health-check.sh \
  --url https://myapp.pane.run \
  --retries 10 \
  --interval 15
```

### PostgreSQL Management

```bash
# Check cluster status
kubectl get cluster -n postgres

# Get credentials
kubectl get secret postgresql-18-superuser -n postgres -o jsonpath='{.data.password}' | base64 -d
kubectl get secret postgresql-16-superuser -n postgres -o jsonpath='{.data.password}' | base64 -d

# Connect to database
kubectl exec -it postgresql-18-1 -n postgres -- psql -U postgres -d defaultdb
kubectl exec -it postgresql-16-1 -n postgres -- psql -U postgres -d app

# Run health checks
./k8s/test-postgres-unified.sh
```

### Traefik Management

```bash
# Check Traefik status
kubectl get pods -n traefik
kubectl get svc traefik -n traefik  # Should show externalIP: 94.130.181.89

# View Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=100 -f

# Upgrade Traefik with custom values
helm upgrade traefik traefik/traefik \
  -n traefik \
  -f k8s/infra/traefik/values-externalips.yaml \
  --wait

# View IngressRoutes
kubectl get ingressroute -A

# Test DNS resolution from Traefik pod
kubectl exec -n traefik deployment/traefik -- nslookup oauth2-proxy.auth.svc.cluster.local
```

### OAuth2-Proxy Authentication

```bash
# Check OAuth2-Proxy status
kubectl get pods -n auth
kubectl logs -n auth -l app=oauth2-proxy --tail=100 -f

# View middleware configuration
kubectl get middleware -n auth
kubectl get middleware oauth2-forward-auth -n auth -o yaml

# Test authentication endpoint
curl -I https://auth.pane.run/oauth2/auth
curl -I https://whoami.pane.run  # Should return 401 if not authenticated

# Update OAuth2-Proxy configuration
helm upgrade oauth2-proxy oauth2-proxy/oauth2-proxy \
  -n auth \
  -f k8s/infra/auth/values.yaml \
  --wait
```

**Protecting an application with OAuth2-Proxy:**

Add middleware reference to your IngressRoute:
```yaml
spec:
  routes:
    - match: Host(`myapp.pane.run`)
      kind: Rule
      middlewares:
        - name: oauth2-forward-auth
          namespace: auth
      services:
        - name: myapp
          port: 80
```

See `k8s/infra/auth/QUICKSTART.md` for detailed guide.

### Monitoring Stack

```bash
# Check Prometheus status
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Check Grafana status
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Access Grafana
# URL: https://grafana.pane.run
# Default credentials: admin / prom-operator

# Check Loki status
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki

# View Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open: http://localhost:9090/targets
```

### Redis Management

```bash
# Check Redis status
kubectl get pods -n storage -l app.kubernetes.io/name=redis

# Connect to Redis CLI
kubectl exec -it -n storage redis-master-0 -c redis -- redis-cli

# Check Redis info
kubectl exec -n storage redis-master-0 -c redis -- redis-cli INFO

# Monitor Redis commands (useful for debugging)
kubectl exec -n storage redis-master-0 -c redis -- redis-cli MONITOR

# Get Redis password (if needed)
kubectl get secret -n storage redis -o jsonpath='{.data.redis-password}' | base64 -d

# Check Redis metrics
kubectl port-forward -n storage svc/redis-metrics 9121:9121
# Metrics available at: http://localhost:9121/metrics
```

## Repository Structure

```
.
├── terraform/                 # Terraform/OpenTofu infrastructure
│   ├── main.tf                # Main config (Hetzner server + Cloudflare DNS)
│   ├── variables.tf           # Variable definitions
│   ├── outputs.tf             # Outputs (IPs, URLs)
│   ├── terraform.tfvars       # Local variables (gitignored)
│   └── terraform.tfvars.example  # Template
│
├── talos/                     # Talos Linux configuration
│   ├── controlplane.yaml      # Control plane config (generated by talosctl)
│   ├── worker.yaml            # Worker config (not used in single-node)
│   ├── talosconfig            # Talos CLI config
│   └── kubeconfig             # Kubernetes CLI config
│
├── k8s/                       # Kubernetes manifests
│   ├── templates/             # Application manifest templates (used by deploy-app.sh)
│   │
│   ├── infra/                 # Infrastructure components
│   │   ├── auth/              # OAuth2-Proxy authentication (auth namespace)
│   │   │   ├── values.yaml    # Helm values for OAuth2-Proxy
│   │   │   ├── middleware-forwardauth.yaml  # Traefik ForwardAuth middleware
│   │   │   ├── QUICKSTART.md  # Quick reference guide
│   │   │   └── README.md      # OAuth2-Proxy setup documentation
│   │   ├── traefik/           # Traefik ingress controller (traefik namespace)
│   │   │   └── values-externalips.yaml  # Helm values with externalIPs configuration
│   │   ├── postgres/          # PostgreSQL clusters (postgres namespace, managed by CloudNative-PG)
│   │   │   ├── postgresql-16-cluster.yaml  # PostgreSQL 16 cluster (50Gi storage)
│   │   │   ├── postgresql-16-secret.yaml
│   │   │   ├── postgresql-18-cluster.yaml  # PostgreSQL 18 cluster (8Gi storage)
│   │   │   └── postgresql-18-secret.yaml
│   │   ├── monitoring/        # Prometheus + Grafana + Loki stack (monitoring namespace)
│   │   │   ├── namespace.yaml
│   │   │   ├── prometheus-values.yaml
│   │   │   ├── loki-values.yaml
│   │   │   ├── grafana-certificate.yaml
│   │   │   └── grafana-ingressroute.yaml
│   │   └── registry/          # Container registry (NOT DEPLOYED - manifests exist but unused)
│   │       ├── namespace.yaml
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── ingress.yaml
│   │
│   ├── storage/               # Storage infrastructure (deployed via Helm, not in repo)
│   │   └── redis              # Redis v8.2.3 (storage namespace, 8Gi PVC)
│   │
│   └── apps/                  # User applications
│       ├── example/           # Example nginx deployment (verify if needed)
│       ├── whoami/            # Test application (with OAuth2-Proxy in reverse proxy mode)
│       ├── writefreely/       # WriteFreely blogging platform (write.pane.run)
│       ├── portainer/         # Container management UI (portainer.pane.run)
│       ├── headlamp/          # Headlamp Kubernetes dashboard (headlamp.pane.run)
│       ├── kubernetes-dashboard/  # Kubernetes official dashboard (active, may be redundant)
│       └── zitadel/           # Zitadel OIDC provider (zitadel.pane.run, uses PostgreSQL 16)
│
├── docs/                      # Documentation
│   ├── readme.md                          # Documentation index
│   ├── authentication-setup-complete.md   # OAuth2-Proxy setup completion
│   ├── deployment-summary-zitadel.md      # Zitadel deployment summary
│   ├── deployment-summary-writefreely.md  # WriteFreely deployment summary
│   ├── backup-procedures.md               # Backup and recovery procedures
│   ├── prometheus-talos-fix.md            # Talos-specific Prometheus fix
│   ├── oauth2-proxy-guide.md              # Comprehensive OAuth2-Proxy guide
│   ├── oauth2-proxy-reverse-proxy-mode.md # Reverse proxy mode setup (WORKING)
│   ├── traefik-externalips-migration.md   # Traefik networking migration summary
│   ├── writefreely.md                     # WriteFreely management guide
│   └── writefreely-quickstart.md          # WriteFreely quick start guide
│
├── scripts/                   # Automation scripts
│   ├── deploy-app.sh          # Deploy app with health checks and rollback
│   ├── health-check.sh        # HTTP health check with retry logic
│   ├── cluster-snapshot.sh    # Comprehensive cluster status in one command (5-7s with GNU Parallel)
│   └── install-parallel.sh    # Install GNU Parallel for faster cluster-snapshot.sh
│
├── backups/                   # Backup directory (gitignored)
│   └── <timestamp>/           # Timestamped backups
│
└── .github/workflows/         # GitHub Actions
    ├── deploy-app.yaml        # Deploy application workflow
    └── rollback.yaml          # Rollback deployment workflow
```

## Architecture Patterns

### Application Deployment Flow

1. **Template-based**: Applications use templates in `k8s/templates/` with variable substitution
2. **Namespaced**: Each app gets its own namespace matching the app name
3. **Ingress**: Traefik IngressRoute with Let's Encrypt TLS certificates
4. **Health Checks**: Automated HTTP checks with configurable retries
5. **Rollback**: Automatic rollback to previous revision on health check failure

### Infrastructure Organization

**k8s/infra/** - Infrastructure and platform components:
- Core services required by applications
- Authentication and ingress
- Databases and storage
- Monitoring and observability
- Deployed via Helm or direct manifests

**k8s/apps/** - User-facing applications:
- End-user services and tools
- Management interfaces
- Deployed via deploy-app.sh or manual apply

### DNS and Ingress

- Wildcard DNS: `*.pane.run` points to server IP (both IPv4/IPv6)
- Subdomains automatically routed via Traefik IngressRoute
- TLS certificates automatically issued by cert-manager + Let's Encrypt
- Applications accessible at `https://<subdomain>.pane.run`

### Traefik Networking Architecture

Traefik uses **externalIPs** for external access instead of `hostNetwork: true`:

```yaml
service:
  type: ClusterIP
  externalIPs:
    - "94.130.181.89"  # Server's public IP
  externalTrafficPolicy: Local
```

**How it works:**
1. Traffic arrives at `94.130.181.89:443` on the host network interface
2. kube-proxy iptables rules match the destination and DNAT to Traefik pod IP
3. Traefik pod runs in normal pod network with full Kubernetes DNS access
4. Can resolve service names like `oauth2-proxy.auth.svc.cluster.local`

**Benefits:**
- Clean DNS resolution for all Kubernetes services
- Runs as non-root user (65532) with no special capabilities
- Standard Kubernetes Service abstraction
- No additional components required (no MetalLB, HAProxy, etc.)
- Uses existing public IP without cloud-specific features

See `docs/traefik-externalips-migration.md` for detailed architecture and migration notes.

### Authentication Architecture

OAuth2-Proxy provides centralized authentication using Zitadel (OIDC provider) in **Reverse Proxy mode**:

**Components:**
- **Zitadel** (`zitadel.pane.run`): Identity provider (OIDC/OAuth2 with PKCE)
- **OAuth2-Proxy**: Authentication gateway in `auth` namespace (reverse proxy mode)
- **Traefik**: Routes requests to OAuth2-Proxy, which handles auth and proxies to backend

**Authentication Flow (Reverse Proxy Mode):**
1. Browser accesses `whoami.pane.run`
2. Traefik routes request to OAuth2-Proxy (NOT to whoami directly)
3. OAuth2-Proxy checks authentication:
   - Not authenticated? → Shows "Sign in with OpenID Connect" page
   - User clicks sign in → Redirects to Zitadel login
4. After successful Zitadel login → Redirects back to OAuth2-Proxy callback
5. OAuth2-Proxy sets authentication cookie and proxies request to whoami service
6. User sees the whoami page content (authenticated)

**Two Authentication Modes:**

**Reverse Proxy Mode (for browsers)** ✅ Currently used for whoami
- Routes: Traefik → OAuth2-Proxy → Backend Service
- Behavior: Redirects to login page, shows HTML sign-in forms
- Use for: Web applications accessed by browsers
- Configuration:
  ```yaml
  # IngressRoute routes TO oauth2-proxy service
  services:
    - name: oauth2-proxy
      namespace: auth
      port: 80
  ```

**ForwardAuth Mode (for APIs)**
- Routes: Traefik → Backend Service (with auth middleware check)
- Behavior: Returns 401 status code (no redirects)
- Use for: API endpoints, machine-to-machine authentication
- Configuration:
  ```yaml
  middlewares:
    - name: oauth2-forward-auth
      namespace: auth
  services:
    - name: my-api  # Direct to backend
      port: 80
  ```

**Protecting new applications:**
1. Deploy separate OAuth2-Proxy instance for the application
2. Configure redirect URL: `https://myapp.pane.run/oauth2/callback`
3. Configure upstream: `http://myapp.myapp.svc.cluster.local:80`
4. Create IngressRoute routing to OAuth2-Proxy service
5. Add redirect URL to Zitadel application

See `docs/oauth2-proxy-reverse-proxy-mode.md` for detailed setup guide.

### PostgreSQL Architecture

- Two clusters managed by CloudNative-PG operator:
  - `postgresql-18` (PostgreSQL 18.0, 8Gi storage) - Used for general purposes
  - `postgresql-16` (PostgreSQL 16.x, 50Gi storage) - Used by Zitadel
- **Important**: Both clusters are in the `postgres` namespace with 1 replica each
  - Note: A separate `postgres-16` namespace exists but is empty (legacy/unused)
- Services for each cluster: `-rw` (read-write), `-r` (read), `-ro` (read-only)
  - Example: `postgresql-16-rw.postgres.svc.cluster.local:5432`
- Automatic superuser credential management via secrets
- Zitadel connects to PostgreSQL 16 via: `postgresql-16-rw.postgres.svc.cluster.local:5432`

### Redis Architecture

- **Deployment**: Helm chart (redis-23.2.12) in `storage` namespace
- **Version**: Redis 8.2.3
- **Mode**: Master-only (single instance with 1 replica)
- **Storage**: 8Gi PVC using local-path storage class
- **Services**:
  - `redis-master.storage.svc.cluster.local:6379` - Main service
  - `redis-metrics.storage.svc.cluster.local:9121` - Prometheus metrics
- **Usage**: Primary cache for Zitadel identity provider
- **Monitoring**: Metrics exporter enabled for Prometheus integration

### Monitoring Architecture

- **Prometheus**: Metrics collection and storage (50Gi PVC)
- **Grafana**: Dashboards and visualization (https://grafana.pane.run, 10Gi PVC)
- **Loki**: Log aggregation and querying (50Gi PVC)
- **kube-prometheus-stack**: Bundled Helm chart for Kubernetes monitoring (v68.5.0)
- **metrics-server**: Kubernetes metrics aggregator (running in kube-system namespace)
- **Note**: Prometheus runs as root (UID 0) on Talos Linux due to permission requirements

See `docs/prometheus-talos-fix.md` for details on Talos-specific configuration.

### Storage

- `local-path` storage class for persistent volumes
- All data stored locally on the single node
- Used by PostgreSQL, Redis, and other stateful applications

**Persistent Volume Claims (PVC) by Component:**
- **PostgreSQL 16**: 50Gi (postgres namespace)
- **PostgreSQL 18**: 8Gi (postgres namespace)
- **Redis**: 8Gi (storage namespace)
- **Prometheus**: 50Gi (monitoring namespace)
- **Grafana**: 10Gi (monitoring namespace)
- **Loki**: 50Gi (monitoring namespace)
- **Portainer**: 10Gi (portainer namespace)
- **WriteFreely**: 2Gi data + 100Mi keys (writefreely namespace)
- **Keycloak** (inactive): 1Gi (keycloak namespace, can be removed)

**Total Storage Used**: ~199Gi of persistent storage

## Active Components

### Infrastructure (k8s/infra/ and Helm deployments)
- ✅ **traefik** (traefik namespace) - Ingress controller with externalIPs, v3.6.0
- ✅ **auth** (auth namespace) - OAuth2-Proxy v7.13.0 authentication gateway
- ✅ **postgres** (postgres namespace) - PostgreSQL 16 (50Gi) & 18 (8Gi) clusters via CloudNative-PG
- ✅ **storage** (storage namespace) - Redis v8.2.3 (8Gi), used by Zitadel
- ✅ **monitoring** (monitoring namespace) - Prometheus (50Gi) + Grafana (10Gi) + Loki (50Gi) stack
- ✅ **cert-manager** (cert-manager namespace) - TLS certificate management v1.19.1
- ✅ **cnpg-system** - CloudNative-PG operator v1.27.1
- ✅ **local-path-storage** - Local path provisioner for PVCs
- ✅ **metrics-server** (kube-system) - Kubernetes metrics aggregator
- ❌ **registry** - Container registry manifests exist but NOT deployed

### Applications (k8s/apps/)
- ✅ **zitadel** (zitadel namespace) - OIDC provider v4.2.0 at https://zitadel.pane.run, uses PostgreSQL 16 + Redis
- ✅ **whoami** (whoami namespace) - Test app with OAuth2-Proxy (reverse proxy mode) at https://whoami.pane.run
- ✅ **writefreely** (writefreely namespace) - Blog platform at https://write.pane.run (2Gi storage)
- ✅ **portainer** (portainer namespace) - Container management UI at https://portainer.pane.run (10Gi storage)
- ✅ **headlamp** (headlamp namespace) - Modern Kubernetes dashboard at https://headlamp.pane.run
- ✅ **kubernetes-dashboard** (kubernetes-dashboard namespace) - Official K8s dashboard at https://k8s.pane.run (may be redundant with Headlamp)
- ⚠️ **example** (example namespace) - Example nginx deployment (verify if needed for testing)

### Legacy/Inactive Components
- ❌ **keycloak** (keycloak namespace) - Superseded by Zitadel, StatefulSet scaled to 0/0, 1Gi PVC can be removed
- ❌ **postgres-16 namespace** - Empty namespace (legacy), actual PostgreSQL clusters are in `postgres` namespace

## Development Workflow

### Adding a New Application

1. Use the deployment script (recommended):
   ```bash
   ./scripts/deploy-app.sh -n <name> -s <subdomain> -i <image> -p <port>
   ```

2. Or manually create manifests in `k8s/apps/<name>/`:
   - `namespace.yaml`
   - `deployment.yaml`
   - `service.yaml`
   - `certificate.yaml` (for TLS)
   - `ingressroute.yaml` (for Traefik)

3. Apply manifests:
   ```bash
   kubectl apply -f k8s/apps/<name>/
   ```

### Modifying Infrastructure

**Terraform (Cloud Infrastructure):**
1. Update `terraform/main.tf` or `terraform/variables.tf`
2. Run `cd terraform && terraform plan` to preview changes
3. Run `terraform apply` to apply changes
4. Note: The server has `lifecycle.ignore_changes` for `user_data` to prevent recreation

**Kubernetes (In-cluster Infrastructure):**
1. Update manifests in `k8s/infra/<component>/`
2. For Helm-managed components, update values.yaml
3. Apply changes:
   ```bash
   kubectl apply -f k8s/infra/<component>/
   # or for Helm
   helm upgrade <release> <chart> -n <namespace> -f k8s/infra/<component>/values.yaml
   ```

### Working with Secrets

- PostgreSQL credentials: Managed by CloudNative-PG operator
- OAuth2-Proxy secrets: In `k8s/infra/auth/secrets.yaml`
- Zitadel secrets: In `k8s/apps/zitadel/secrets.yaml`
- All sensitive values should use Kubernetes secrets, never committed to git

## Testing and Monitoring

### Cluster Snapshot

Get a comprehensive overview of the entire cluster in one command:

```bash
# Display cluster snapshot (all info in one view)
./scripts/cluster-snapshot.sh

# Save snapshot to timestamped file
./scripts/cluster-snapshot.sh --save
```

The snapshot includes:
- Cluster and node information (versions, resources, health)
- All namespaces and workload counts
- Detailed workloads by namespace (deployments, statefulsets, pods)
- Helm releases and versions
- Ingress routes and external URLs
- TLS certificates status
- Storage (PVCs, storage classes, usage summary)
- PostgreSQL clusters (CloudNative-PG)
- Redis instances
- Authentication stack (OAuth2-Proxy, Zitadel)
- Monitoring stack (Prometheus, Grafana, Loki)
- Resource usage (CPU, memory by pod and namespace)
- Pod health status and restart counts
- Recent events
- Legacy/inactive components
- Complete cluster statistics

### Application Testing

```bash
# Test PostgreSQL clusters
./k8s/test-postgres-unified.sh

# Test specific application
./scripts/health-check.sh --url https://<subdomain>.pane.run

# Check overall cluster health
kubectl get all -A
talosctl health --nodes talos.pane.run

# Test authentication flow
curl -I https://whoami.pane.run  # Should redirect or return 401
```

## Troubleshooting

### Pod Issues
```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --tail=100 -f
```

### Deployment Rollback
```bash
kubectl rollout history deployment/<name> -n <namespace>
kubectl rollout undo deployment/<name> -n <namespace>
kubectl rollout undo deployment/<name> -n <namespace> --to-revision=<N>
```

### Ingress/TLS Issues
```bash
kubectl get ingressroute -A
kubectl get certificate -A
kubectl describe certificate <name> -n <namespace>
kubectl logs -n cert-manager -l app=cert-manager
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
```

### Talos Issues
```bash
talosctl logs --nodes talos.pane.run
talosctl logs --nodes talos.pane.run --follow controller-runtime
talosctl logs --nodes talos.pane.run kubelet
```

### Authentication Issues
```bash
# Check OAuth2-Proxy logs
kubectl logs -n auth -l app=oauth2-proxy

# Check Zitadel logs
kubectl logs -n zitadel -l app.kubernetes.io/name=zitadel

# Verify middleware is applied
kubectl describe ingressroute <app> -n <namespace>

# Test auth endpoint
curl -v https://auth.pane.run/oauth2/auth
```

## GitHub Actions

- **Deploy Application**: Automatically deploys when changes pushed to `k8s/apps/*` or manually triggered
- **Rollback**: Manually triggered workflow to rollback deployments

Both workflows require repository secrets for kubeconfig access.

## Important Files Not Committed

- `terraform/terraform.tfvars` - Terraform variables (API tokens, zone IDs)
- `terraform/terraform.tfstate` - Terraform state file
- `talos/talosconfig` - Talos CLI authentication
- `talos/kubeconfig` - Kubernetes CLI authentication
- `talos/controlplane.yaml` - Actual control plane config (contains secrets)
- All `secrets.yaml` files in k8s directories
- `backups/` - Backup directory with cluster exports

Use `.example` files as templates where available (e.g., `terraform/terraform.tfvars.example`).

## Backup and Recovery

See `docs/backup-procedures.md` for comprehensive backup and recovery procedures.

**Quick backup commands:**
```bash
# Backup PostgreSQL databases
kubectl exec -n postgres postgresql-16-1 -- pg_dumpall -U postgres | gzip > postgres-16-backup.sql.gz
kubectl exec -n postgres postgresql-18-1 -- pg_dumpall -U postgres | gzip > postgres-18-backup.sql.gz

# Export all Kubernetes resources
kubectl get all -A -o yaml > cluster-backup.yaml

# Backup WriteFreely data
./scripts/backup-writefreely.sh
```

## Monitoring and Observability

- **Grafana**: https://grafana.pane.run (admin / prom-operator)
- **Prometheus**: Port-forward to access UI
- **Loki**: Integrated with Grafana for log queries
- **Traefik Dashboard**: https://traefik.pane.run (if enabled)

## Documentation

All comprehensive guides are in the `docs/` directory:
- `docs/readme.md` - Documentation index
- `docs/oauth2-proxy-reverse-proxy-mode.md` - Authentication setup
- `docs/traefik-externalips-migration.md` - Networking architecture
- `docs/writefreely.md` - Blog platform management
- `docs/backup-procedures.md` - Backup and recovery
- `docs/prometheus-talos-fix.md` - Monitoring fixes
