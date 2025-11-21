#!/bin/bash
set -e

echo "=================================================="
echo "PostgreSQL Unified Test Suite"
echo "Testing both PG16 and PG18 in 'postgres' namespace"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local command="$2"

    echo -n "Testing: $test_name... "

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "=================================================="
echo "Testing PostgreSQL 18"
echo "=================================================="
echo ""

# Get PostgreSQL 18 superuser password
PG18_PASSWORD=$(kubectl get secret postgresql-18-superuser -n postgres -o jsonpath='{.data.password}' | base64 -d)

# Test PostgreSQL 18 pod status
run_test "PostgreSQL 18 pod is running" \
    "kubectl get pod postgresql-18-1 -n postgres --no-headers | grep -q Running"

# Test PostgreSQL 18 cluster status
run_test "PostgreSQL 18 cluster is healthy" \
    "kubectl get cluster postgresql-18 -n postgres -o jsonpath='{.status.phase}' | grep -q 'healthy'"

# Test PostgreSQL 18 local connection
run_test "PostgreSQL 18 local connection" \
    "kubectl exec postgresql-18-1 -n postgres -- psql -U postgres -d defaultdb -c 'SELECT 1' -t | grep -q 1"

# Test PostgreSQL 18 remote connection
run_test "PostgreSQL 18 remote connection (rw service)" \
    "kubectl run pg18-test-\$RANDOM --image=postgres:18 --restart=Never -n postgres --env='PGPASSWORD=$PG18_PASSWORD' --rm -i --command -- psql -h postgresql-18-rw.postgres.svc.cluster.local -U postgres -d defaultdb -c 'SELECT 1' -t 2>/dev/null | grep -q 1"

# Test PostgreSQL 18 CRUD operations
run_test "PostgreSQL 18 CRUD operations" \
    "kubectl exec postgresql-18-1 -n postgres -- psql -U postgres -d defaultdb -c 'CREATE TABLE IF NOT EXISTS test_crud (id SERIAL PRIMARY KEY, data TEXT); INSERT INTO test_crud (data) VALUES (\"test\"); SELECT COUNT(*) FROM test_crud; DROP TABLE test_crud;' 2>/dev/null | grep -q 1"

# Test PostgreSQL 18 version
echo -n "PostgreSQL 18 version: "
kubectl exec postgresql-18-1 -n postgres -- psql -U postgres -d defaultdb -c "SELECT version()" -t 2>/dev/null | grep -o "PostgreSQL [0-9]*\.[0-9]*" || echo "Unknown"

echo ""
echo "=================================================="
echo "Testing PostgreSQL 16"
echo "=================================================="
echo ""

# Get PostgreSQL 16 passwords
PG16_SUPERUSER_PASSWORD=$(kubectl get secret postgresql-16-superuser -n postgres -o jsonpath='{.data.password}' | base64 -d)
PG16_APP_PASSWORD=$(kubectl get secret postgresql-16-credentials -n postgres -o jsonpath='{.data.password}' | base64 -d)

# Test PostgreSQL 16 pod status
run_test "PostgreSQL 16 pod is running" \
    "kubectl get pod postgresql-16-1 -n postgres --no-headers | grep -q Running"

# Test PostgreSQL 16 cluster status
run_test "PostgreSQL 16 cluster is healthy" \
    "kubectl get cluster postgresql-16 -n postgres -o jsonpath='{.status.phase}' | grep -q 'healthy'"

# Test PostgreSQL 16 local connection
run_test "PostgreSQL 16 local connection (postgres user)" \
    "kubectl exec postgresql-16-1 -n postgres -- psql -U postgres -d app -c 'SELECT 1' -t | grep -q 1"

# Test PostgreSQL 16 remote connection with superuser
run_test "PostgreSQL 16 remote connection (postgres user)" \
    "kubectl run pg16-test-\$RANDOM --image=postgres:16 --restart=Never -n postgres --env='PGPASSWORD=$PG16_SUPERUSER_PASSWORD' --rm -i --command -- psql -h postgresql-16-rw.postgres.svc.cluster.local -U postgres -d app -c 'SELECT 1' -t 2>/dev/null | grep -q 1"

# Test PostgreSQL 16 remote connection with app user
run_test "PostgreSQL 16 remote connection (app user)" \
    "kubectl run pg16-app-test-\$RANDOM --image=postgres:16 --restart=Never -n postgres --env='PGPASSWORD=$PG16_APP_PASSWORD' --rm -i --command -- psql -h postgresql-16-rw.postgres.svc.cluster.local -U app -d app -c 'SELECT 1' -t 2>/dev/null | grep -q 1"

# Test PostgreSQL 16 CRUD operations
run_test "PostgreSQL 16 CRUD operations (postgres user)" \
    "kubectl exec postgresql-16-1 -n postgres -- psql -U postgres -d app -c 'CREATE TABLE IF NOT EXISTS test_crud (id SERIAL PRIMARY KEY, data TEXT); INSERT INTO test_crud (data) VALUES (\"test\"); SELECT COUNT(*) FROM test_crud; DROP TABLE test_crud;' 2>/dev/null | grep -q 1"

# Test PostgreSQL 16 version
echo -n "PostgreSQL 16 version: "
kubectl exec postgresql-16-1 -n postgres -- psql -U postgres -d app -c "SELECT version()" -t 2>/dev/null | grep -o "PostgreSQL [0-9]*\.[0-9]*" || echo "Unknown"

echo ""
echo "=================================================="
echo "Service Endpoints"
echo "=================================================="
echo ""

echo "All PostgreSQL Services:"
kubectl get svc -n postgres

echo ""
echo "=================================================="
echo "Test Summary"
echo "=================================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed!${NC}"
    exit 1
fi
