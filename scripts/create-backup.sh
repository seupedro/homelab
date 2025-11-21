#!/bin/bash
set -e

TIMESTAMP="20251120-171450"
BACKUP_DIR="/home/seupedro/homelab/backups/$TIMESTAMP"

echo "=== Creating Pre-Migration Backup ==="
echo "Timestamp: $TIMESTAMP"
echo "Backup directory: $BACKUP_DIR"

# 1. Export namespace resources
echo -e "\n=== Exporting namespace resources ==="
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  echo "Backing up namespace: $ns"
  kubectl get all,secrets,configmaps,pvc,ingressroute,certificate,middleware \
    -n $ns -o yaml > "$BACKUP_DIR/namespace-$ns.yaml" 2>/dev/null || true
done

# 2. Export cluster-wide resources
echo -e "\n=== Exporting cluster-wide resources ==="
kubectl get clusterrole,clusterrolebinding,storageclass,ingressclass \
  -o yaml > "$BACKUP_DIR/cluster-resources.yaml" 2>/dev/null || true

# 3. Export CRDs
echo -e "\n=== Exporting CRDs ==="
kubectl get crd -o yaml > "$BACKUP_DIR/crds.yaml" 2>/dev/null || true

# 4. Backup PostgreSQL databases
echo -e "\n=== Backing up PostgreSQL databases ==="
echo "Backing up PostgreSQL 16 - zitadel database..."
kubectl exec -n postgres postgresql-16-1 -- \
  pg_dump -U postgres zitadel 2>/dev/null | \
  gzip > "$BACKUP_DIR/postgresql-16-zitadel-$TIMESTAMP.sql.gz" || \
  echo "Warning: Could not backup PostgreSQL 16 zitadel database"

echo "Backing up PostgreSQL 16 - all databases..."
kubectl exec -n postgres postgresql-16-1 -- \
  pg_dumpall -U postgres 2>/dev/null | \
  gzip > "$BACKUP_DIR/postgresql-16-all-$TIMESTAMP.sql.gz" || \
  echo "Warning: Could not backup PostgreSQL 16 all databases"

echo "Backing up PostgreSQL 18 - all databases..."
kubectl exec -n postgres postgresql-18-1 -- \
  pg_dumpall -U postgres 2>/dev/null | \
  gzip > "$BACKUP_DIR/postgresql-18-all-$TIMESTAMP.sql.gz" || \
  echo "Warning: Could not backup PostgreSQL 18 all databases"

# 5. Export Helm values
echo -e "\n=== Exporting Helm values ==="
helm list -A --output json > "$BACKUP_DIR/helm-list.json"

for release in cert-manager cnpg headlamp kube-prometheus-stack loki oauth2-proxy redis traefik zitadel; do
  ns=$(helm list -A --output json | jq -r ".[] | select(.name==\"$release\") | .namespace")
  if [ -n "$ns" ]; then
    echo "Exporting Helm values: $release ($ns)"
    helm get values $release -n $ns > "$BACKUP_DIR/helm-values-$release.yaml" 2>/dev/null || true
    helm get manifest $release -n $ns > "$BACKUP_DIR/helm-manifest-$release.yaml" 2>/dev/null || true
  fi
done

# 6. Document current state
echo -e "\n=== Documenting current state ==="
kubectl cluster-info > "$BACKUP_DIR/cluster-info.txt" 2>/dev/null || true
kubectl get nodes -o wide > "$BACKUP_DIR/nodes.txt" 2>/dev/null || true
kubectl version > "$BACKUP_DIR/versions.txt" 2>/dev/null || true
kubectl get all -A > "$BACKUP_DIR/all-resources.txt" 2>/dev/null || true
helm list -A > "$BACKUP_DIR/helm-releases.txt" 2>/dev/null || true
kubectl get ingressroute -A > "$BACKUP_DIR/ingressroutes.txt" 2>/dev/null || true
kubectl get certificate -A > "$BACKUP_DIR/certificates.txt" 2>/dev/null || true
kubectl get cluster -n postgres > "$BACKUP_DIR/postgres-clusters.txt" 2>/dev/null || true
kubectl get pvc -A > "$BACKUP_DIR/pvcs.txt" 2>/dev/null || true
kubectl get pv > "$BACKUP_DIR/pvs.txt" 2>/dev/null || true

# 7. Create tarball
echo -e "\n=== Creating tarball ==="
cd /home/seupedro/homelab/backups
tar czf "k8s-backup-$TIMESTAMP.tar.gz" "$TIMESTAMP" 2>/dev/null || true

# 8. Summary
echo -e "\n=== Backup Summary ==="
echo "Backup location: $BACKUP_DIR"
echo "Tarball: /home/seupedro/homelab/backups/k8s-backup-$TIMESTAMP.tar.gz"
echo ""
du -sh "$BACKUP_DIR"
echo ""
echo "Files created:"
ls -lh "$BACKUP_DIR" | tail -n +2 | awk '{print $9, "-", $5}'
echo ""
echo "Backup completed successfully!"
