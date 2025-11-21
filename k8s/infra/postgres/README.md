# PostgreSQL Deployments

This directory contains PostgreSQL cluster deployments managed by CloudNative-PG operator.

## Overview

Both PostgreSQL 16 and PostgreSQL 18 instances are deployed in the **postgres** namespace with 1 replica each.

## Clusters

### PostgreSQL 18
- **Name**: `postgresql-18`
- **Version**: PostgreSQL 18.0
- **Namespace**: `postgres`
- **Storage**: 8Gi (local-path)
- **Instances**: 1
- **Default Database**: `defaultdb`
- **Owner**: `postgres`

### PostgreSQL 16
- **Name**: `postgresql-16`
- **Version**: PostgreSQL 16.11
- **Namespace**: `postgres`
- **Storage**: 50Gi (local-path)
- **Instances**: 1
- **Default Database**: `app`
- **Owner**: `app`

## Services

Each cluster exposes three services:

### PostgreSQL 18 Services
- `postgresql-18-rw.postgres.svc.cluster.local:5432` - Read-Write
- `postgresql-18-r.postgres.svc.cluster.local:5432` - Read
- `postgresql-18-ro.postgres.svc.cluster.local:5432` - Read-Only (no endpoints with 1 replica)

### PostgreSQL 16 Services
- `postgresql-16-rw.postgres.svc.cluster.local:5432` - Read-Write
- `postgresql-16-r.postgres.svc.cluster.local:5432` - Read
- `postgresql-16-ro.postgres.svc.cluster.local:5432` - Read-Only (no endpoints with 1 replica)

## Credentials

Credentials are stored in Kubernetes secrets:

### PostgreSQL 18
- **Superuser Secret**: `postgresql-18-superuser`
- **Username**: `postgres`
- **Password**: Retrieved from secret

### PostgreSQL 16
- **Superuser Secret**: `postgresql-16-superuser`
- **Username**: `postgres`
- **Password**: Retrieved from secret
- **App User Secret**: `postgresql-16-credentials`
- **App Username**: `app`
- **App Password**: Retrieved from secret

## Connection Examples

### Get Passwords

```bash
# PostgreSQL 18 superuser password
kubectl get secret postgresql-18-superuser -n postgres -o jsonpath='{.data.password}' | base64 -d

# PostgreSQL 16 superuser password
kubectl get secret postgresql-16-superuser -n postgres -o jsonpath='{.data.password}' | base64 -d

# PostgreSQL 16 app user password
kubectl get secret postgresql-16-credentials -n postgres -o jsonpath='{.data.password}' | base64 -d
```

### Connect from Within Cluster

```bash
# PostgreSQL 18
psql -h postgresql-18-rw.postgres.svc.cluster.local -U postgres -d defaultdb

# PostgreSQL 16 (superuser)
psql -h postgresql-16-rw.postgres.svc.cluster.local -U postgres -d app

# PostgreSQL 16 (app user)
psql -h postgresql-16-rw.postgres.svc.cluster.local -U app -d app
```

### Connect via kubectl exec

```bash
# PostgreSQL 18
kubectl exec -it postgresql-18-1 -n postgres -- psql -U postgres -d defaultdb

# PostgreSQL 16
kubectl exec -it postgresql-16-1 -n postgres -- psql -U postgres -d app
```

## Testing

Run the test script to verify both clusters are healthy:

```bash
/home/seupedro/homelab/k8s/test-postgres-unified.sh
```

Quick health check:

```bash
kubectl get cluster -n postgres
kubectl get pods -n postgres
```

## Deployment Files

- `namespace.yaml` - Postgres namespace definition
- `postgresql-18-secret.yaml` - PostgreSQL 18 credentials
- `postgresql-18-cluster.yaml` - PostgreSQL 18 cluster configuration
- `postgresql-16-secret.yaml` - PostgreSQL 16 credentials
- `postgresql-16-cluster.yaml` - PostgreSQL 16 cluster configuration

## Deploying

To deploy or update the clusters:

```bash
kubectl apply -f /home/seupedro/homelab/k8s/postgres/namespace.yaml
kubectl apply -f /home/seupedro/homelab/k8s/postgres/postgresql-18-secret.yaml
kubectl apply -f /home/seupedro/homelab/k8s/postgres/postgresql-18-cluster.yaml
kubectl apply -f /home/seupedro/homelab/k8s/postgres/postgresql-16-secret.yaml
kubectl apply -f /home/seupedro/homelab/k8s/postgres/postgresql-16-cluster.yaml
```

## Monitoring

Check cluster status:

```bash
kubectl get cluster -n postgres
kubectl describe cluster postgresql-18 -n postgres
kubectl describe cluster postgresql-16 -n postgres
```

Check pod logs:

```bash
kubectl logs -f postgresql-18-1 -n postgres
kubectl logs -f postgresql-16-1 -n postgres
```

## Notes

- Both clusters use `enableSuperuserAccess: true` for automatic superuser password management
- Read-only services will not have endpoints until additional replicas are added
- Storage uses `local-path` storage class
- CloudNative-PG operator manages automatic failover, backups, and updates
