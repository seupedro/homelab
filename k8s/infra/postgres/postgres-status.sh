#!/bin/bash

echo "========================================"
echo "PostgreSQL Clusters Status"
echo "========================================"
echo ""

echo "--- Clusters ---"
kubectl get cluster -n postgres
echo ""

echo "--- Pods ---"
kubectl get pods -n postgres
echo ""

echo "--- Services ---"
kubectl get svc -n postgres
echo ""

echo "--- Quick Health Test ---"
echo "PostgreSQL 18:"
kubectl exec postgresql-18-1 -n postgres -- psql -U postgres -d defaultdb -c "SELECT 'PG18 ✓' as status;" -t 2>/dev/null | xargs
echo ""
echo "PostgreSQL 16:"
kubectl exec postgresql-16-1 -n postgres -- psql -U postgres -d app -c "SELECT 'PG16 ✓' as status;" -t 2>/dev/null | xargs
echo ""

echo "========================================"
echo "✓ Status check complete!"
echo "========================================"
echo ""
echo "For detailed tests, run:"
echo "  /home/seupedro/homelab/k8s/test-postgres-unified.sh"
echo ""
echo "For connection information, see:"
echo "  /home/seupedro/homelab/k8s/postgres/README.md"
