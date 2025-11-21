#!/bin/bash
set -e

echo "=================================================="
echo "PostgreSQL Cluster Test Suite"
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
echo "Testing PostgreSQL 18 (storage namespace)"
echo "=================================================="
echo ""

# Get PostgreSQL 18 superuser password
PG18_PASSWORD=$(kubectl get secret postgresql-superuser -n storage -o jsonpath='{.data.password}' | base64 -d)

# Test PostgreSQL 18 pod status
run_test "PostgreSQL 18 pod is running" \
    "kubectl get pod postgresql-1 -n storage --no-headers | grep -q Running"

# Test PostgreSQL 18 cluster status
run_test "PostgreSQL 18 cluster is healthy" \
    "kubectl get cluster postgresql -n storage -o jsonpath='{.status.phase}' | grep -q 'healthy'"

# Test PostgreSQL 18 local connection
run_test "PostgreSQL 18 local connection" \
    "kubectl exec postgresql-1 -n storage -- psql -U postgres -d defaultdb -c 'SELECT 1' -t | grep -q 1"

# Test PostgreSQL 18 remote connection
run_test "PostgreSQL 18 remote connection (rw service)" \
    "kubectl run pg18-test-\$RANDOM --image=postgres:18 --restart=Never -n storage --env='PGPASSWORD=$PG18_PASSWORD' --rm -i --command -- psql -h postgresql-rw.storage.svc.cluster.local -U postgres -d defaultdb -c 'SELECT 1' -t | grep -q 1"

# Test PostgreSQL 18 version
echo -n "PostgreSQL 18 version: "
kubectl exec postgresql-1 -n storage -- psql -U postgres -d defaultdb -c "SELECT version()" -t | grep -o "PostgreSQL [0-9]*\.[0-9]*" || echo "Unknown"

echo ""
echo "=================================================="
echo "Testing PostgreSQL 16 (postgres-16 namespace)"
echo "=================================================="
echo ""

# Get PostgreSQL 16 passwords
PG16_SUPERUSER_PASSWORD=$(kubectl get secret postgres-16-superuser -n postgres-16 -o jsonpath='{.data.password}' | base64 -d)
PG16_APP_PASSWORD=$(kubectl get secret postgres-16-credentials -n postgres-16 -o jsonpath='{.data.password}' | base64 -d)

# Test PostgreSQL 16 pod status
run_test "PostgreSQL 16 pod is running" \
    "kubectl get pod postgres-16-1 -n postgres-16 --no-headers | grep -q Running"

# Test PostgreSQL 16 cluster status
run_test "PostgreSQL 16 cluster is healthy" \
    "kubectl get cluster postgres-16 -n postgres-16 -o jsonpath='{.status.phase}' | grep -q 'healthy'"

# Test PostgreSQL 16 local connection
run_test "PostgreSQL 16 local connection (postgres user)" \
    "kubectl exec postgres-16-1 -n postgres-16 -- psql -U postgres -d app -c 'SELECT 1' -t | grep -q 1"

# Test PostgreSQL 16 remote connection with superuser
run_test "PostgreSQL 16 remote connection (postgres user)" \
    "kubectl run pg16-test-\$RANDOM --image=postgres:16 --restart=Never -n postgres-16 --env='PGPASSWORD=$PG16_SUPERUSER_PASSWORD' --rm -i --command -- psql -h postgres-16-rw.postgres-16.svc.cluster.local -U postgres -d app -c 'SELECT 1' -t | grep -q 1"

# Test PostgreSQL 16 remote connection with app user
run_test "PostgreSQL 16 remote connection (app user)" \
    "kubectl run pg16-app-test-\$RANDOM --image=postgres:16 --restart=Never -n postgres-16 --env='PGPASSWORD=$PG16_APP_PASSWORD' --rm -i --command -- psql -h postgres-16-rw.postgres-16.svc.cluster.local -U app -d app -c 'SELECT 1' -t | grep -q 1"

# Test PostgreSQL 16 version
echo -n "PostgreSQL 16 version: "
kubectl exec postgres-16-1 -n postgres-16 -- psql -U postgres -d app -c "SELECT version()" -t | grep -o "PostgreSQL [0-9]*\.[0-9]*" || echo "Unknown"

echo ""
echo "=================================================="
echo "Testing CRUD Operations"
echo "=================================================="
echo ""

# Test CRUD on PostgreSQL 18
run_test "PostgreSQL 18 CRUD operations" \
    "kubectl exec postgresql-1 -n storage -- psql -U postgres -d defaultdb -c 'CREATE TABLE test_crud (id SERIAL PRIMARY KEY, data TEXT); INSERT INTO test_crud (data) VALUES (\"test\"); SELECT COUNT(*) FROM test_crud; DROP TABLE test_crud;' | grep -q 1"

# Test CRUD on PostgreSQL 16
run_test "PostgreSQL 16 CRUD operations (app user)" \
    "kubectl run pg16-crud-test-\$RANDOM --image=postgres:16 --restart=Never -n postgres-16 --env='PGPASSWORD=$PG16_APP_PASSWORD' --rm -i --command -- psql -h postgres-16-rw.postgres-16.svc.cluster.local -U app -d app -c 'CREATE TABLE test_crud (id SERIAL PRIMARY KEY, data TEXT); INSERT INTO test_crud (data) VALUES (\"test\"); SELECT COUNT(*) FROM test_crud; DROP TABLE test_crud;' | grep -q 1"

echo ""
echo "=================================================="
echo "Service Endpoints"
echo "=================================================="
echo ""

echo "PostgreSQL 18 Services:"
kubectl get svc -n storage | grep postgresql

echo ""
echo "PostgreSQL 16 Services:"
kubectl get svc -n postgres-16 | grep postgres-16

echo ""
echo "=================================================="
echo "Test Summary"
echo "=================================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
