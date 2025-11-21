# Backup and Recovery Procedures

**Created:** 2025-11-20
**Purpose:** Critical backup procedures for GitOps migration

## Quick Reference

### Emergency Rollback Commands
```bash
# Rollback via Git
cd /home/seupedro/homelab
git log --oneline -10
git revert <commit-hash>
flux reconcile kustomization --all

# Rollback Helm release
helm rollback <release-name> -n <namespace>

# Restore from backup
kubectl apply -f /home/seupedro/homelab/backups/<timestamp>/
```

## Phase 0: Pre-Migration Backup

### 1. Archive Current k8s/ Directory
```bash
# Create timestamped backup
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/home/seupedro/homelab/backups/$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

# Copy entire k8s directory
cp -r /home/seupedro/homelab/k8s "$BACKUP_DIR/k8s-original"

# Create tarball
cd /home/seupedro/homelab/backups
tar czf "k8s-backup-$TIMESTAMP.tar.gz" "$TIMESTAMP"
```

### 2. Export All Kubernetes Resources
```bash
# Export all resources for each namespace
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  echo "Backing up namespace: $ns"
  kubectl get all,secrets,configmaps,pvc,ingressroute,certificate,middleware -n $ns -o yaml > "$BACKUP_DIR/namespace-$ns.yaml"
done

# Export cluster-wide resources
kubectl get clusterrole,clusterrolebinding,storageclass,ingressclass -o yaml > "$BACKUP_DIR/cluster-resources.yaml"

# Export CRDs
kubectl get crd -o yaml > "$BACKUP_DIR/crds.yaml"
```

### 3. Backup PostgreSQL Databases
```bash
# PostgreSQL 16 - Zitadel database
kubectl exec -n postgres postgresql-16-1 -- \
  pg_dump -U postgres zitadel | \
  gzip > "$BACKUP_DIR/postgresql-16-zitadel-$TIMESTAMP.sql.gz"

# PostgreSQL 16 - All databases
kubectl exec -n postgres postgresql-16-1 -- \
  pg_dumpall -U postgres | \
  gzip > "$BACKUP_DIR/postgresql-16-all-$TIMESTAMP.sql.gz"

# PostgreSQL 18 - All databases
kubectl exec -n postgres postgresql-18-1 -- \
  pg_dumpall -U postgres | \
  gzip > "$BACKUP_DIR/postgresql-18-all-$TIMESTAMP.sql.gz"

# Verify backups created
ls -lh "$BACKUP_DIR"/*.sql.gz
```

### 4. Export Helm Values
```bash
# Export all Helm release values
for release in $(helm list -A -o json | jq -r '.[] | "\(.name):\(.namespace)"'); do
  name=$(echo $release | cut -d: -f1)
  ns=$(echo $release | cut -d: -f2)
  echo "Exporting Helm values: $name ($ns)"
  helm get values $name -n $ns > "$BACKUP_DIR/helm-values-$name.yaml"
  helm get manifest $name -n $ns > "$BACKUP_DIR/helm-manifest-$name.yaml"
done
```

### 5. Document Current State
```bash
# Cluster info
kubectl cluster-info > "$BACKUP_DIR/cluster-info.txt"
kubectl get nodes -o wide > "$BACKUP_DIR/nodes.txt"
kubectl version > "$BACKUP_DIR/versions.txt"

# All namespaces and resources
kubectl get all -A > "$BACKUP_DIR/all-resources.txt"

# Helm releases
helm list -A > "$BACKUP_DIR/helm-releases.txt"

# IngressRoutes and Certificates
kubectl get ingressroute -A > "$BACKUP_DIR/ingressroutes.txt"
kubectl get certificate -A > "$BACKUP_DIR/certificates.txt"

# PostgreSQL cluster status
kubectl get cluster -n postgres > "$BACKUP_DIR/postgres-clusters.txt"

# Storage
kubectl get pvc -A > "$BACKUP_DIR/pvcs.txt"
kubectl get pv > "$BACKUP_DIR/pvs.txt"
```

### 6. Create Backup Manifest
```bash
cat > "$BACKUP_DIR/BACKUP-MANIFEST.md" << 'EOF'
# Backup Manifest

**Timestamp:** $TIMESTAMP
**Cluster:** pane-homelab
**Node:** talos-o82-nnf

## Contents

### Directories
- k8s-original/ - Complete copy of k8s/ directory structure

### Kubernetes Exports
- namespace-*.yaml - All resources per namespace
- cluster-resources.yaml - Cluster-wide resources
- crds.yaml - Custom Resource Definitions

### Database Backups
- postgresql-16-zitadel-*.sql.gz - Zitadel database (PostgreSQL 16)
- postgresql-16-all-*.sql.gz - All PostgreSQL 16 databases
- postgresql-18-all-*.sql.gz - All PostgreSQL 18 databases

### Helm Releases
- helm-values-*.yaml - Helm values for each release
- helm-manifest-*.yaml - Rendered manifests for each release

### State Documentation
- cluster-info.txt - Cluster information
- nodes.txt - Node details
- versions.txt - Kubernetes and kubectl versions
- all-resources.txt - All cluster resources
- helm-releases.txt - Helm release listing
- ingressroutes.txt - Traefik IngressRoutes
- certificates.txt - TLS Certificates
- postgres-clusters.txt - PostgreSQL cluster status
- pvcs.txt - Persistent Volume Claims
- pvs.txt - Persistent Volumes

## Recovery Instructions

### Full Cluster Recovery
1. Ensure Talos cluster is running
2. Apply CRDs first:
   kubectl apply -f crds.yaml
3. Apply cluster resources:
   kubectl apply -f cluster-resources.yaml
4. Restore namespaces one by one:
   kubectl apply -f namespace-<name>.yaml

### Database Recovery
PostgreSQL 16:
  kubectl exec -i -n postgres postgresql-16-1 -- \
    psql -U postgres < postgresql-16-all-*.sql.gz

PostgreSQL 18:
  kubectl exec -i -n postgres postgresql-18-1 -- \
    psql -U postgres < postgresql-18-all-*.sql.gz

### Helm Release Recovery
helm install <name> <chart> -n <namespace> -f helm-values-<name>.yaml

## Validation Checklist
- [ ] All namespaces restored
- [ ] All deployments running
- [ ] All services accessible
- [ ] All IngressRoutes working
- [ ] All TLS certificates valid
- [ ] All databases accessible
- [ ] PostgreSQL clusters healthy
- [ ] Authentication working
- [ ] Monitoring collecting metrics
EOF

# Replace timestamp placeholder
sed -i "s/\$TIMESTAMP/$TIMESTAMP/g" "$BACKUP_DIR/BACKUP-MANIFEST.md"
```

## Recovery Procedures

### Scenario 1: Rollback Single Component
```bash
# Identify the component
kubectl get helmrelease -A
kubectl describe helmrelease <name> -n <namespace>

# Revert Git commit
cd /home/seupedro/homelab
git log --oneline -20
git revert <commit-hash>
git push

# Force Flux reconciliation
flux reconcile source git homelab
flux reconcile helmrelease <name> -n <namespace>
```

### Scenario 2: Rollback Entire Phase
```bash
# Find commits for the phase
git log --oneline --since="1 hour ago"

# Revert all commits in reverse order
git revert <commit3>
git revert <commit2>
git revert <commit1>
git push

# Reconcile all Flux resources
flux reconcile kustomization --all
```

### Scenario 3: Emergency Full Rollback
```bash
# Option A: Git reset (destructive)
cd /home/seupedro/homelab
git log --oneline -20
git reset --hard <commit-before-migration>
git push --force

# Option B: Manual restore from backup
BACKUP_DIR="/home/seupedro/homelab/backups/<timestamp>"
kubectl apply -f "$BACKUP_DIR/namespace-*.yaml"

# Restore Helm releases
helm install traefik traefik/traefik -n traefik \
  -f "$BACKUP_DIR/helm-values-traefik.yaml"
```

### Scenario 4: Database Recovery
```bash
# Stop applications using the database
kubectl scale deployment -n zitadel zitadel --replicas=0

# Restore database
gunzip -c postgresql-16-zitadel-*.sql.gz | \
kubectl exec -i -n postgres postgresql-16-1 -- \
  psql -U postgres -d zitadel

# Restart applications
kubectl scale deployment -n zitadel zitadel --replicas=1
```

### Scenario 5: Complete Cluster Rebuild
```bash
# 1. Fresh Talos cluster (existing)
# 2. Install Flux CD
flux install

# 3. Restore CRDs
kubectl apply -f backups/<timestamp>/crds.yaml

# 4. Restore namespace resources
for f in backups/<timestamp>/namespace-*.yaml; do
  kubectl apply -f "$f"
done

# 5. Restore databases
# (See Scenario 4)

# 6. Verify all services
kubectl get all -A
kubectl get certificate -A
kubectl get ingressroute -A
```

## Health Check Scripts

### Quick Health Check
```bash
#!/bin/bash
# /home/seupedro/homelab/scripts/health-check-all.sh

echo "=== Cluster Health ==="
kubectl get nodes

echo -e "\n=== Flux Status ==="
flux check

echo -e "\n=== All Pods ==="
kubectl get pods -A | grep -v Running | grep -v Completed

echo -e "\n=== Helm Releases ==="
helm list -A

echo -e "\n=== PostgreSQL Clusters ==="
kubectl get cluster -n postgres

echo -e "\n=== Certificates ==="
kubectl get certificate -A | grep -v True

echo -e "\n=== IngressRoutes ==="
kubectl get ingressroute -A

echo -e "\n=== Critical URLs ==="
for url in \
  https://traefik.pane.run \
  https://grafana.pane.run \
  https://zitadel.pane.run \
  https://auth.pane.run \
  https://whoami.pane.run \
  https://write.pane.run; do

  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -k "$url")
  echo "$url - HTTP $STATUS"
done
```

### Database Health Check
```bash
#!/bin/bash
# /home/seupedro/homelab/scripts/db-health-check.sh

echo "=== PostgreSQL 16 ==="
kubectl exec -n postgres postgresql-16-1 -- psql -U postgres -c "SELECT version();"
kubectl exec -n postgres postgresql-16-1 -- psql -U postgres -c "\l"

echo -e "\n=== PostgreSQL 18 ==="
kubectl exec -n postgres postgresql-18-1 -- psql -U postgres -c "SELECT version();"
kubectl exec -n postgres postgresql-18-1 -- psql -U postgres -c "\l"

echo -e "\n=== Redis ==="
kubectl exec -n storage redis-master-0 -- redis-cli ping
```

## Backup Automation

### Automated Daily Backups (Future)
```yaml
# k8s/infrastructure/backup/cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: postgres
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:16
            command:
            - /bin/bash
            - -c
            - |
              pg_dump -U postgres zitadel | \
              gzip > /backup/zitadel-$(date +%Y%m%d).sql.gz
            volumeMounts:
            - name: backup
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: postgres-backup
```

## Verification Checklist

After any restore operation, verify:

- [ ] All namespaces present: `kubectl get ns`
- [ ] All pods running: `kubectl get pods -A`
- [ ] Flux healthy: `flux check`
- [ ] Helm releases deployed: `helm list -A`
- [ ] PostgreSQL clusters healthy: `kubectl get cluster -n postgres`
- [ ] All certificates valid: `kubectl get certificate -A`
- [ ] All IngressRoutes working: `kubectl get ingressroute -A`
- [ ] Traefik accessible: `https://traefik.pane.run`
- [ ] Grafana accessible: `https://grafana.pane.run`
- [ ] Zitadel login works: `https://zitadel.pane.run`
- [ ] OAuth2-Proxy auth works: `https://whoami.pane.run`
- [ ] WriteFreely accessible: `https://write.pane.run`
- [ ] Database connections working
- [ ] No errors in logs: `kubectl logs -n <namespace> <pod>`

## Backup Schedule Recommendations

- **Before each migration phase:** Full backup
- **Daily:** PostgreSQL databases (automated CronJob)
- **Weekly:** Full cluster export
- **Before Helm upgrades:** Export current values
- **Before destructive operations:** Always backup first

## Important Notes

1. **Never delete PVCs without backup:** Data loss is permanent
2. **Test restore procedures regularly:** Backups are useless if untested
3. **Keep backups off-cluster:** Don't rely on cluster storage alone
4. **Document secrets separately:** Some secrets may not export correctly
5. **Verify backup integrity:** Check file sizes, test database restores
6. **Maintain backup retention:** Keep at least 7 days of backups
7. **Encrypt sensitive backups:** Database dumps contain sensitive data

## Backup Storage Locations

- **Primary:** `/home/seupedro/homelab/backups/` (local filesystem)
- **Secondary:** Git repository (manifests only, no secrets)
- **Tertiary:** External storage (future - S3, NFS, etc.)
