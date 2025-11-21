#!/bin/bash
# Quick PostgreSQL Test Script

echo "========================================"
echo "PostgreSQL Quick Health Check"
echo "========================================"
echo ""

echo "--- Cluster Status ---"
kubectl get cluster -A
echo ""

echo "--- Pod Status ---"
echo "PostgreSQL 18:"
kubectl get pods -n storage | grep postgresql
echo ""
echo "PostgreSQL 16:"
kubectl get pods -n postgres-16
echo ""

echo "--- Testing PostgreSQL 18 ---"
kubectl exec postgresql-1 -n storage -- psql -U postgres -d defaultdb -c "SELECT 'PG18 ✓' as status, version();" 2>/dev/null
echo ""

echo "--- Testing PostgreSQL 16 ---"
kubectl exec postgres-16-1 -n postgres-16 -- psql -U postgres -d app -c "SELECT 'PG16 ✓' as status, version();" 2>/dev/null
echo ""

echo "--- Service Endpoints ---"
echo "PostgreSQL 18:"
kubectl get svc -n storage | grep postgresql
echo ""
echo "PostgreSQL 16:"
kubectl get svc -n postgres-16
echo ""

echo "========================================"
echo "✓ Quick test complete!"
echo "========================================"
echo ""
echo "For detailed connection information, see:"
echo "  /home/seupedro/homelab/k8s/postgres-connection-info.md"
