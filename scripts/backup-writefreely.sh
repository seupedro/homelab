#!/bin/bash
#
# WriteFreely Backup Script
# Backs up SQLite database and encryption keys
#

set -euo pipefail

# Configuration
BACKUP_DIR="$HOME/homelab/backups/writefreely"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RETENTION_DAYS=7

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl."
    exit 1
fi

# Check if WriteFreely is running
if ! kubectl get deployment writefreely -n writefreely &> /dev/null; then
    log_error "WriteFreely deployment not found in namespace 'writefreely'"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

log_info "Starting WriteFreely backup..."
log_info "Backup directory: $BACKUP_DIR"
log_info "Timestamp: $TIMESTAMP"

# Get pod name
POD_NAME=$(kubectl get pod -n writefreely -l app=writefreely -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
    log_error "No running WriteFreely pod found"
    exit 1
fi

log_info "Found pod: $POD_NAME"

# Backup SQLite database
log_info "Backing up SQLite database..."
if kubectl exec -n writefreely "$POD_NAME" -- cat /data/writefreely.db > "$BACKUP_DIR/writefreely-db-$TIMESTAMP.db"; then
    DB_SIZE=$(du -h "$BACKUP_DIR/writefreely-db-$TIMESTAMP.db" | cut -f1)
    log_info "✓ Database backed up successfully ($DB_SIZE)"
else
    log_error "Failed to backup database"
    exit 1
fi

# Backup encryption keys
log_info "Backing up encryption keys..."
if kubectl exec -n writefreely "$POD_NAME" -- tar czf /tmp/keys-backup.tar.gz -C /writefreely keys 2>/dev/null; then
    if kubectl cp "writefreely/$POD_NAME:/tmp/keys-backup.tar.gz" "$BACKUP_DIR/writefreely-keys-$TIMESTAMP.tar.gz" 2>/dev/null; then
        KEYS_SIZE=$(du -h "$BACKUP_DIR/writefreely-keys-$TIMESTAMP.tar.gz" | cut -f1)
        log_info "✓ Encryption keys backed up successfully ($KEYS_SIZE)"

        # Cleanup temp file in pod
        kubectl exec -n writefreely "$POD_NAME" -- rm -f /tmp/keys-backup.tar.gz 2>/dev/null || true
    else
        log_warn "Failed to copy keys backup from pod"
    fi
else
    log_warn "Failed to create keys backup in pod"
fi

# Create a metadata file
cat > "$BACKUP_DIR/writefreely-metadata-$TIMESTAMP.txt" <<EOF
Backup Information
==================
Timestamp: $TIMESTAMP
Date: $(date)
Pod: $POD_NAME
Namespace: writefreely

Files:
- Database: writefreely-db-$TIMESTAMP.db
- Keys: writefreely-keys-$TIMESTAMP.tar.gz

Restore Instructions:
--------------------
1. Database:
   kubectl cp ./writefreely-db-$TIMESTAMP.db writefreely/$POD_NAME:/data/writefreely-restore.db
   kubectl exec -n writefreely $POD_NAME -- mv /data/writefreely.db /data/writefreely.db.old
   kubectl exec -n writefreely $POD_NAME -- mv /data/writefreely-restore.db /data/writefreely.db
   kubectl rollout restart deployment/writefreely -n writefreely

2. Keys:
   kubectl cp ./writefreely-keys-$TIMESTAMP.tar.gz writefreely/$POD_NAME:/tmp/keys-restore.tar.gz
   kubectl exec -n writefreely $POD_NAME -- tar xzf /tmp/keys-restore.tar.gz -C /writefreely
   kubectl rollout restart deployment/writefreely -n writefreely
EOF

log_info "✓ Metadata file created"

# Cleanup old backups
log_info "Cleaning up old backups (retention: $RETENTION_DAYS days)..."
DELETED_COUNT=0

# Delete old database backups
while IFS= read -r file; do
    rm -f "$file"
    ((DELETED_COUNT++))
done < <(find "$BACKUP_DIR" -name "writefreely-db-*.db" -mtime +"$RETENTION_DAYS" 2>/dev/null)

# Delete old key backups
while IFS= read -r file; do
    rm -f "$file"
    ((DELETED_COUNT++))
done < <(find "$BACKUP_DIR" -name "writefreely-keys-*.tar.gz" -mtime +"$RETENTION_DAYS" 2>/dev/null)

# Delete old metadata files
while IFS= read -r file; do
    rm -f "$file"
    ((DELETED_COUNT++))
done < <(find "$BACKUP_DIR" -name "writefreely-metadata-*.txt" -mtime +"$RETENTION_DAYS" 2>/dev/null)

if [ $DELETED_COUNT -gt 0 ]; then
    log_info "✓ Deleted $DELETED_COUNT old backup file(s)"
else
    log_info "No old backups to delete"
fi

# Summary
echo ""
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "Backup completed successfully!"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "Backup files:"
log_info "  - $BACKUP_DIR/writefreely-db-$TIMESTAMP.db"
log_info "  - $BACKUP_DIR/writefreely-keys-$TIMESTAMP.tar.gz"
log_info "  - $BACKUP_DIR/writefreely-metadata-$TIMESTAMP.txt"
echo ""

# List all backups
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -name "writefreely-db-*.db" | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log_info "Total backups: $TOTAL_BACKUPS"
log_info "Total size: $TOTAL_SIZE"
