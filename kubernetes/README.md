# Kubernetes GitOps Structure

This directory contains the Flux GitOps configuration for the homelab cluster.

## Directory Structure

```
kubernetes/
├── clusters/
│   └── production/          # Cluster-specific configurations
│       ├── infrastructure.yaml  # Infrastructure Kustomization
│       └── apps.yaml           # Applications Kustomization
├── infrastructure/
│   ├── sources/            # Helm repositories and other sources
│   └── base/               # Core infrastructure components
│       ├── traefik/        # Ingress controller
│       ├── cert-manager/   # TLS certificate management
│       └── local-path-provisioner/  # Persistent storage
└── apps/
    └── base/               # Application deployments
```

## Components

### Infrastructure

1. **Traefik** - Ingress controller running on host network (ports 80/443)
   - Dashboard: `https://traefik.pane.run`
   - Automatically routes *.pane.run to cluster services

2. **cert-manager** - Automated TLS certificate management
   - Let's Encrypt integration (staging + production)
   - Automatic certificate renewal

3. **local-path-provisioner** - Persistent storage provisioner
   - Default StorageClass for PVCs
   - Storage path: `/var/lib/rancher/local-path-provisioner`

## Deployment Order

Flux automatically handles dependencies:
1. `infrastructure-sources` - Helm repositories
2. `infrastructure` - Core components (storage, ingress, certs)
3. `apps` - Your applications

## Adding New Applications

1. Create a new directory under `kubernetes/apps/base/my-app/`
2. Add your manifests (Deployment, Service, Ingress, etc.)
3. Create a `kustomization.yaml` in the app directory
4. Reference it in `kubernetes/apps/base/kustomization.yaml`
5. Commit and push - Flux will automatically deploy

## Example Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - myapp.pane.run
      secretName: myapp-tls
  rules:
    - host: myapp.pane.run
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

## Useful Commands

```bash
# Check Flux status
flux get all -A

# Reconcile immediately (don't wait for interval)
flux reconcile kustomization infrastructure --with-source

# Check infrastructure deployment
kubectl get helmrelease -A

# View Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik

# Check cert-manager certificates
kubectl get certificate -A
```

## Troubleshooting

### Flux not reconciling
```bash
flux logs --level=error
flux reconcile source git flux-system
```

### Traefik not routing traffic
```bash
kubectl get ingressroute -A
kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=100
```

### Certificates not issuing
```bash
kubectl get certificaterequest -A
kubectl describe certificate <name> -n <namespace>
kubectl logs -n cert-manager -l app=cert-manager
```

## Important Notes

- **Email for Let's Encrypt**: Update `admin@pane.run` in `cert-manager/letsencrypt-issuer.yaml` to your email
- **DNS**: Ensure `*.pane.run` points to your server's IP (already configured via Terraform)
- **Firewall**: Ports 80 and 443 must be open on your Hetzner server
- **Storage**: PVs are created on the node at `/var/lib/rancher/local-path-provisioner`
