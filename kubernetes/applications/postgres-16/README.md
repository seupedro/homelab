# PostgreSQL 16 - Default Homelab Database

This is the default PostgreSQL 16 database for homelab applications, managed by CloudNative-PG operator v1.27.1.

## Overview

- **Cluster Name**: `postgres-16`
- **Namespace**: `postgres-16`
- **PostgreSQL Version**: 16 (latest)
- **Instances**: 1 (single instance)
- **Storage**: 50Gi (local-path storage class)
- **Database**: `app` (default application database)
- **User**: `app` (application user with full access to `app` database)

## Connection Information

### Internal Cluster Access

Applications running in the Kubernetes cluster can connect using:

**Service DNS Names**:
- **Read-Write**: `postgres-16-rw.postgres-16.svc.cluster.local:5432`
- **Read-Only**: `postgres-16-ro.postgres-16.svc.cluster.local:5432` (for read replicas, if configured)

**Connection String Format**:
```
postgresql://app:<password>@postgres-16-rw.postgres-16.svc.cluster.local:5432/app?sslmode=require
```

### Credentials

Application credentials are stored in the Kubernetes secret:
- **Secret Name**: `postgres-16-app-user`
- **Namespace**: `postgres-16`
- **Keys**: `username`, `password`

**Retrieve credentials**:
```bash
# Get username
kubectl get secret postgres-16-app-user -n postgres-16 -o jsonpath='{.data.username}' | base64 -d

# Get password
kubectl get secret postgres-16-app-user -n postgres-16 -o jsonpath='{.data.password}' | base64 -d
```

**Superuser credentials** (for administrative tasks):
- **Secret Name**: `postgres-16-superuser`
- **Username**: `postgres`
- **Namespace**: `postgres-16`

### Using in Application Deployments

**Example Deployment with Environment Variables**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: my-app:latest
        env:
        - name: DB_HOST
          value: postgres-16-rw.postgres-16.svc.cluster.local
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          value: app
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: postgres-16-app-user
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-16-app-user
              key: password
        - name: DATABASE_URL
          value: postgresql://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=require
```

**Example with envFrom** (inject all secret keys):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: my-app:latest
        envFrom:
        - secretRef:
            name: postgres-16-app-user
```

## Management

### Access PostgreSQL Shell

```bash
# As superuser
kubectl exec -it -n postgres-16 postgres-16-1 -- psql -U postgres

# As app user
kubectl exec -it -n postgres-16 postgres-16-1 -- psql -U app -d app
```

### Create Additional Databases

```bash
kubectl exec -it -n postgres-16 postgres-16-1 -- psql -U postgres -c "CREATE DATABASE mydb;"
```

### Create Additional Users

```bash
# Create user
kubectl exec -it -n postgres-16 postgres-16-1 -- psql -U postgres -c "CREATE USER myuser WITH PASSWORD 'securepassword';"

# Grant privileges
kubectl exec -it -n postgres-16 postgres-16-1 -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE mydb TO myuser;"
```

### Monitoring

View cluster status:
```bash
kubectl get cluster -n postgres-16
kubectl describe cluster postgres-16 -n postgres-16
```

View pod status:
```bash
kubectl get pods -n postgres-16
kubectl logs -n postgres-16 postgres-16-1
```

## Configuration

The PostgreSQL cluster is configured with optimized settings for homelab use:
- Max connections: 200
- Shared buffers: 256MB
- Effective cache size: 1GB
- Work memory: ~1.3MB per connection

Resource limits:
- CPU: 500m (request) / 2 (limit)
- Memory: 512Mi (request) / 2Gi (limit)

## Backup and Recovery

> **Note**: Backup configuration is currently commented out in `cluster.yaml`.
> To enable automated backups to S3/MinIO, uncomment the backup section and configure credentials.

## Troubleshooting

**Check cluster health**:
```bash
kubectl get cluster -n postgres-16 postgres-16
```

**View operator logs**:
```bash
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg
```

**Check PostgreSQL logs**:
```bash
kubectl logs -n postgres-16 postgres-16-1
```

**Restart cluster** (if needed):
```bash
kubectl rollout restart deployment -n postgres-16
```

## Architecture

```
┌─────────────────────────────────────┐
│  cnpg-system namespace              │
│  ┌───────────────────────────────┐  │
│  │ CloudNative-PG Operator       │  │
│  │ (manages clusters)            │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
              │
              ▼ manages
┌─────────────────────────────────────┐
│  postgres-16 namespace              │
│  ┌───────────────────────────────┐  │
│  │ PostgreSQL 16 Cluster         │  │
│  │ - 1 instance (postgres-16-1)  │  │
│  │ - 50Gi storage                │  │
│  │ - Service: postgres-16-rw     │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ Secrets                       │  │
│  │ - postgres-16-app-user        │  │
│  │ - postgres-16-superuser       │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Next Steps

1. Wait for ArgoCD to sync (automatic within 3 minutes)
2. Verify operator is running: `kubectl get pods -n cnpg-system`
3. Verify cluster is ready: `kubectl get cluster -n postgres-16`
4. Test connection from an application pod
5. (Optional) Configure backups for production use

## References

- [CloudNative-PG Documentation](https://cloudnative-pg.io/documentation/current/)
- [PostgreSQL 16 Release Notes](https://www.postgresql.org/docs/16/release-16.html)
- [Operator GitHub](https://github.com/cloudnative-pg/cloudnative-pg)
