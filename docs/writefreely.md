# WriteFreely Documentation

## Overview

WriteFreely is a federated blogging platform deployed at **https://write.pane.run**

- **Deployment Date**: 2025-11-19
- **Namespace**: `writefreely`
- **Mode**: Multi-user blogging platform
- **Registration**: Invite-only
- **Federation**: Disabled (no ActivityPub/Fediverse integration)
- **Database**: SQLite3 (file-based)

## Access Information

### Admin Account

**URL**: https://write.pane.run/login

**Admin Username**: `seupedro`
**Admin Password**: `changeme123` (CHANGE THIS IMMEDIATELY!)

**First Steps**:
1. Visit https://write.pane.run
2. Click "Login" in the top right
3. Enter admin credentials
4. Go to Settings → Change password
5. Update your profile and preferences

## Architecture

### Components

```
writefreely/
├── Deployment (writefreely)
│   └── 1 replica
│   └── Image: writeas/writefreely:latest
│   └── Port: 8080
├── Service (ClusterIP)
├── IngressRoute (Traefik)
├── Certificate (Let's Encrypt TLS)
└── Persistent Volumes
    ├── writefreely-keys (100Mi) - encryption keys, CSRF tokens
    └── writefreely-data (2Gi) - SQLite database
```

### Resource Allocation

- **CPU Request**: 100m
- **CPU Limit**: 500m
- **Memory Request**: 128Mi
- **Memory Limit**: 512Mi
- **Replicas**: 1 (single instance - required for SQLite)

### Storage

- **Keys Volume**: `/writefreely/keys` (100Mi)
  - Stores encryption keys
  - CSRF tokens
  - Session data
  - **Critical**: Must persist across restarts

- **Data Volume**: `/data` (2Gi)
  - SQLite database: `/data/writefreely.db`
  - All posts, users, and content
  - **Critical**: Contains all blog data

## User Management

### Creating Admin Users (CLI)

```bash
# Create a new admin user via CLI
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "cd /go && /go/cmd/writefreely/writefreely --create-admin <username>:<password>"

# Example
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "cd /go && /go/cmd/writefreely/writefreely --create-admin alice:SecurePass123"
```

**Note**: Username must be at least 3 characters and cannot be reserved words like "admin".

### Inviting Users (Web Interface)

Since registration is invite-only, users need invite codes:

1. Log in as admin at https://write.pane.run/login
2. Go to Settings → Invites
3. Generate invite codes
4. Share codes with users
5. Users visit https://write.pane.run and click "Sign up with invite code"

### User Management Commands

```bash
# List all users (via database)
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "sqlite3 /data/writefreely.db 'SELECT username, created FROM users;'"

# Delete a user (requires direct database access)
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "sqlite3 /data/writefreely.db \"DELETE FROM users WHERE username='<username>';\""
```

## Operations

### Checking Status

```bash
# Check deployment status
kubectl get deployment -n writefreely
kubectl get pods -n writefreely
kubectl get svc -n writefreely

# Check logs
kubectl logs -n writefreely deployment/writefreely --tail=50 -f

# Check certificate status
kubectl get certificate -n writefreely

# Check ingress
kubectl get ingressroute -n writefreely
```

### Restarting WriteFreely

```bash
# Restart deployment
kubectl rollout restart deployment/writefreely -n writefreely

# Check rollout status
kubectl rollout status deployment/writefreely -n writefreely
```

### Viewing Logs

```bash
# Tail logs
kubectl logs -n writefreely deployment/writefreely --tail=100 -f

# Get all logs
kubectl logs -n writefreely deployment/writefreely

# Previous container logs (if crashed)
kubectl logs -n writefreely deployment/writefreely --previous
```

### Accessing the Container

```bash
# Exec into the running container
kubectl exec -it -n writefreely deployment/writefreely -- /bin/sh

# Run commands directly
kubectl exec -n writefreely deployment/writefreely -- <command>
```

## Configuration

### Config File Location

The configuration is stored in a ConfigMap: `writefreely-config`

```bash
# View current configuration
kubectl get configmap writefreely-config -n writefreely -o yaml

# Edit configuration
kubectl edit configmap writefreely-config -n writefreely

# After editing, restart deployment
kubectl rollout restart deployment/writefreely -n writefreely
```

### Key Configuration Settings

**Location**: `k8s/apps/writefreely/configmap.yaml`

```ini
[server]
port = 8080
bind = 0.0.0.0

[database]
type = sqlite3
filename = /data/writefreely.db

[app]
site_name = Write
site_description = A place to write
host = https://write.pane.run
single_user = false              # Multi-user mode
open_registration = false        # Invite-only
min_username_len = 3
max_blogs = 5                    # Max blogs per user
federation = false               # ActivityPub disabled
public_stats = true
local_timeline = true
user_invites = user              # Users can generate invites
default_visibility = public
```

### Enabling Federation (ActivityPub)

To enable Fediverse integration:

1. Edit `k8s/apps/writefreely/configmap.yaml`
2. Change `federation = false` to `federation = true`
3. Apply: `kubectl apply -f k8s/apps/writefreely/configmap.yaml`
4. Restart: `kubectl rollout restart deployment/writefreely -n writefreely`

Users will then be discoverable on Mastodon and other ActivityPub platforms at:
- `@username@write.pane.run`

### Changing Registration Mode

**Invite-only (current)**:
```ini
open_registration = false
user_invites = user
```

**Open registration**:
```ini
open_registration = true
user_invites = user
```

**Closed (admin only)**:
```ini
open_registration = false
user_invites = admin
```

## Backup and Restore

### Backup Strategy

**What to backup**:
1. SQLite database: `/data/writefreely.db`
2. Encryption keys: `/writefreely/keys/*`

### Database Backup

```bash
# Create a backup of the SQLite database
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "sqlite3 /data/writefreely.db '.backup /data/writefreely-backup-$(date +%Y%m%d).db'"

# Copy backup to local machine
kubectl cp writefreely/$(kubectl get pod -n writefreely -l app=writefreely -o jsonpath='{.items[0].metadata.name}'):/data/writefreely-backup-$(date +%Y%m%d).db ./writefreely-backup-$(date +%Y%m%d).db

# Or use kubectl exec with redirect
kubectl exec -n writefreely deployment/writefreely -- cat /data/writefreely.db > writefreely-backup-$(date +%Y%m%d).db
```

### Automated Backup Script

Create `~/homelab/scripts/backup-writefreely.sh`:

```bash
#!/bin/bash
BACKUP_DIR="$HOME/homelab/backups/writefreely"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup database
echo "Backing up WriteFreely database..."
kubectl exec -n writefreely deployment/writefreely -- cat /data/writefreely.db \
  > "$BACKUP_DIR/writefreely-db-$TIMESTAMP.db"

echo "Backup completed: $BACKUP_DIR/writefreely-db-$TIMESTAMP.db"

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "writefreely-db-*.db" -mtime +7 -delete
```

### Restore from Backup

```bash
# Copy backup to pod
kubectl cp ./writefreely-backup.db \
  writefreely/$(kubectl get pod -n writefreely -l app=writefreely -o jsonpath='{.items[0].metadata.name}'):/data/writefreely-restore.db

# Exec into pod and replace database
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "mv /data/writefreely.db /data/writefreely.db.old && mv /data/writefreely-restore.db /data/writefreely.db"

# Restart deployment
kubectl rollout restart deployment/writefreely -n writefreely
```

### Keys Backup

```bash
# Create tarball of keys directory
kubectl exec -n writefreely deployment/writefreely -- tar czf /tmp/keys-backup.tar.gz -C /writefreely keys

# Copy to local machine
kubectl cp writefreely/$(kubectl get pod -n writefreely -l app=writefreely -o jsonpath='{.items[0].metadata.name}'):/tmp/keys-backup.tar.gz ./writefreely-keys-$(date +%Y%m%d).tar.gz
```

## Troubleshooting

### Common Issues

#### 1. Pod Not Starting

```bash
# Check pod status
kubectl get pods -n writefreely

# Describe pod for events
kubectl describe pod -n writefreely <pod-name>

# Check logs
kubectl logs -n writefreely <pod-name>
```

#### 2. Database Connection Errors

```bash
# Check if database file exists
kubectl exec -n writefreely deployment/writefreely -- ls -lh /data/

# Check database integrity
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "sqlite3 /data/writefreely.db 'PRAGMA integrity_check;'"
```

#### 3. TLS Certificate Issues

```bash
# Check certificate status
kubectl get certificate -n writefreely
kubectl describe certificate write-pane-run-tls -n writefreely

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50
```

#### 4. Site Not Accessible

```bash
# Check ingress route
kubectl get ingressroute -n writefreely
kubectl describe ingressroute writefreely -n writefreely

# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=50

# Test service internally
kubectl run curl-test --image=curlimages/curl -it --rm --restart=Never -- \
  curl -v http://writefreely.writefreely.svc.cluster.local:8080
```

#### 5. Can't Create Users

```bash
# Check if username meets requirements (min 3 chars, not reserved)
# Try with different username

# Check database write permissions
kubectl exec -n writefreely deployment/writefreely -- ls -l /data/

# Check logs for specific errors
kubectl logs -n writefreely deployment/writefreely --tail=100 | grep -i error
```

### Database Maintenance

```bash
# Check database size
kubectl exec -n writefreely deployment/writefreely -- du -sh /data/writefreely.db

# Vacuum database (reclaim space)
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "sqlite3 /data/writefreely.db 'VACUUM;'"

# Check table sizes
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "sqlite3 /data/writefreely.db \".tables\""
```

### Performance Monitoring

```bash
# Check resource usage
kubectl top pod -n writefreely

# Check database queries (requires logging)
kubectl logs -n writefreely deployment/writefreely | grep -i "sql\|query"
```

## Upgrading

### Upgrading WriteFreely

```bash
# Check current version
kubectl get deployment writefreely -n writefreely -o jsonpath='{.spec.template.spec.containers[0].image}'

# Update to new version
kubectl set image deployment/writefreely writefreely=writeas/writefreely:v0.16.0 -n writefreely

# Or edit deployment
kubectl edit deployment writefreely -n writefreely

# Watch rollout
kubectl rollout status deployment/writefreely -n writefreely

# If issues occur, rollback
kubectl rollout undo deployment/writefreely -n writefreely
```

## Customization

### Themes and Templates

WriteFreely supports custom themes. To customize:

1. Create a ConfigMap with custom templates
2. Mount to `/writefreely/templates` or `/writefreely/static`
3. Restart deployment

### Custom CSS

Add custom CSS via the web interface:
1. Log in as admin
2. Go to Customize → Custom CSS
3. Add your CSS
4. Save

## Security

### Changing Admin Password

**Via Web Interface** (recommended):
1. Log in at https://write.pane.run/login
2. Go to Settings → Account
3. Change password

**Via CLI**:
```bash
# Reset password requires direct database access
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "cd /go && /go/cmd/writefreely/writefreely --reset-pass <username>"
```

### Security Best Practices

1. **Change default password immediately**
2. **Enable HTTPS only** (already configured via Traefik)
3. **Regular backups** (database + keys)
4. **Keep WriteFreely updated**
5. **Monitor logs for suspicious activity**
6. **Limit invite generation** (admin-only if needed)
7. **Enable federation carefully** (exposes posts to Fediverse)

## Monitoring

### Health Checks

The deployment has built-in health checks:

**Liveness Probe**: `GET /` every 10s
**Readiness Probe**: `GET /` every 5s

### Manual Health Check

```bash
# Using the health check script
~/homelab/scripts/health-check.sh --url https://write.pane.run

# Using curl
curl -I https://write.pane.run
```

### Metrics

To track usage:
1. Public stats enabled: https://write.pane.run/stats
2. Check database for user counts:
   ```bash
   kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
     "sqlite3 /data/writefreely.db 'SELECT COUNT(*) FROM users;'"
   ```

## Uninstalling

To completely remove WriteFreely:

```bash
# Delete all resources
kubectl delete namespace writefreely

# Or delete individual resources
kubectl delete -f ~/homelab/k8s/apps/writefreely/

# Note: PVCs are deleted with namespace, which removes all data
# Backup first if you want to preserve data!
```

## Manifest Files

All deployment manifests are in: `~/homelab/k8s/apps/writefreely/`

- `namespace.yaml` - Namespace definition
- `configmap.yaml` - Configuration (config.ini)
- `pvc.yaml` - Persistent volume claims (keys + data)
- `init-job.yaml` - Database initialization job (run once)
- `deployment.yaml` - Main application deployment
- `service.yaml` - ClusterIP service
- `certificate.yaml` - TLS certificate
- `ingressroute.yaml` - Traefik ingress route

## Important Notes

1. **Single Instance Only**: WriteFreely uses SQLite, so only 1 replica is supported
2. **No PostgreSQL Support**: WriteFreely only supports MySQL and SQLite3 (we use SQLite3)
3. **Keys Are Critical**: The `/writefreely/keys` directory contains encryption keys - losing it means losing access to encrypted data
4. **Database Backups**: SQLite database is in `/data/writefreely.db` - back it up regularly
5. **Binary Location**: WriteFreely binary is at `/go/cmd/writefreely/writefreely` (not in PATH)

## Support and Resources

- **WriteFreely Docs**: https://writefreely.org/docs
- **GitHub**: https://github.com/writefreely/writefreely
- **Forum**: https://discuss.write.as
- **Federation Guide**: https://writefreely.org/docs/latest/admin/federation

## Quick Reference

```bash
# Status check
kubectl get all -n writefreely

# View logs
kubectl logs -n writefreely deployment/writefreely -f

# Restart
kubectl rollout restart deployment/writefreely -n writefreely

# Create user
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "cd /go && /go/cmd/writefreely/writefreely --create-admin <user>:<pass>"

# Backup database
kubectl exec -n writefreely deployment/writefreely -- cat /data/writefreely.db \
  > writefreely-backup-$(date +%Y%m%d).db

# Health check
~/homelab/scripts/health-check.sh --url https://write.pane.run
```

---

**Last Updated**: 2025-11-19
**Maintainer**: seupedro
**Version**: WriteFreely latest (container image)
