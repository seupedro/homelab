# Homelab Automation Scripts

This directory contains automation scripts for managing and monitoring the Kubernetes homelab cluster.

## Available Scripts

### 1. cluster-snapshot.sh

**Purpose**: Get a comprehensive overview of the entire Kubernetes cluster in one command.

**Performance**: ⚡ **Optimized for speed** - Uses GNU Parallel for maximum performance with progress bar (~5-7 seconds with GNU Parallel, ~15 seconds fallback mode).

**Usage**:
```bash
# Display full cluster snapshot
./scripts/cluster-snapshot.sh

# Save snapshot to timestamped file
./scripts/cluster-snapshot.sh --save
```

**What it shows**:
- ✅ Cluster and node information (versions, health, resources)
- ✅ All namespaces and resource counts
- ✅ Workloads by namespace (deployments, statefulsets, daemonsets)
- ✅ Helm releases and versions
- ✅ Ingress routes and TLS certificates
- ✅ Storage (PVCs, storage classes, usage summary)
- ✅ PostgreSQL clusters (CloudNative-PG status)
- ✅ Redis instances
- ✅ Authentication stack (OAuth2-Proxy, Zitadel)
- ✅ Monitoring stack (Prometheus, Grafana, Loki)
- ✅ Resource usage (CPU, memory by pod/namespace)
- ✅ Pod health status and restart counts
- ✅ Recent cluster events
- ✅ Legacy/inactive components
- ✅ Complete cluster statistics

**Requirements**:
- kubectl (required)
- GNU Parallel (recommended for best performance - install with `sudo apt install parallel` or `brew install parallel`)
- helm (optional, for Helm release info)
- talosctl (optional, for Talos version info)
- jq (optional, for better formatting)
- column (optional, for tabular formatting)

**Performance Details**:

**With GNU Parallel (recommended)**:
- Uses advanced job management for optimal parallel execution
- Built-in progress bar shows completion percentage
- Automatic load balancing across CPU cores
- **Execution time**: ~5-7 seconds for a 20-namespace cluster

**Fallback Mode (without GNU Parallel)**:
- Uses shell background jobs
- Simple progress counter
- **Execution time**: ~15 seconds for a 20-namespace cluster

**Installation of GNU Parallel**:

Quick install using helper script:
```bash
./scripts/install-parallel.sh
```

Or manually:
```bash
# Debian/Ubuntu
sudo apt install parallel

# macOS
brew install parallel

# Arch Linux
sudo pacman -S parallel
```

**User Experience**:
- Automatic detection of GNU Parallel
- Falls back gracefully if not installed
- Real-time progress bar (with GNU Parallel) or counter (fallback mode)
- Clear completion indicators

**Output**: Colored, formatted text output with clear sections and separators.

---

### 2. deploy-app.sh

**Purpose**: Deploy applications to Kubernetes using templates with automated health checks and rollback capability.

**Usage**:
```bash
./scripts/deploy-app.sh \
  --name <app-name> \
  --subdomain <subdomain> \
  --image <docker-image> \
  --port <port> \
  --replicas <replicas>
```

**Example**:
```bash
./scripts/deploy-app.sh \
  --name myapp \
  --subdomain myapp \
  --image nginx:latest \
  --port 80 \
  --replicas 2
```

**What it does**:
1. Generates Kubernetes manifests from templates in `k8s/templates/`
2. Saves manifests to `k8s/apps/<app-name>/`
3. Applies manifests to the cluster
4. Runs health checks to verify deployment
5. Automatically rolls back if health checks fail

**Generates**:
- `namespace.yaml` - Dedicated namespace for the app
- `deployment.yaml` - Deployment with specified replicas
- `service.yaml` - ClusterIP service
- `certificate.yaml` - Let's Encrypt TLS certificate
- `ingressroute.yaml` - Traefik IngressRoute with TLS

**Requirements**:
- kubectl
- Access to cluster with write permissions
- Templates in `k8s/templates/` directory

---

### 3. health-check.sh

**Purpose**: Perform HTTP health checks with configurable retries and intervals.

**Usage**:
```bash
./scripts/health-check.sh \
  --url <https://app.pane.run> \
  --retries <number> \
  --interval <seconds>
```

**Example**:
```bash
# Check if application is responding
./scripts/health-check.sh \
  --url https://myapp.pane.run \
  --retries 10 \
  --interval 15
```

**What it does**:
1. Makes HTTP requests to specified URL
2. Retries on failure with configurable intervals
3. Reports success/failure status
4. Returns appropriate exit codes for automation

**Use cases**:
- Verify application deployment
- Test ingress configuration
- Automated deployment validation
- Post-deployment verification

**Requirements**:
- curl

---

## Script Conventions

### Exit Codes
- `0` - Success
- `1` - Error or failure

### Colors
All scripts use colored output for better readability:
- 🔴 Red - Errors
- 🟢 Green - Success
- 🟡 Yellow - Warnings
- 🔵 Blue - Headers
- 🟣 Magenta - Sections
- 🔷 Cyan - Separators

### Output Format
- Clear section headers with separators
- Organized by logical groupings
- Tabular output where appropriate
- Timestamps for snapshots/logs

## Adding New Scripts

When adding new automation scripts:

1. **Make executable**: `chmod +x scripts/<script-name>.sh`
2. **Add shebang**: Use `#!/usr/bin/env bash`
3. **Add description**: Include header comment explaining purpose
4. **Use colors**: Maintain consistent color scheme
5. **Error handling**: Use `set -euo pipefail` for safety
6. **Document**: Update this README with usage info
7. **Update CLAUDE.md**: Add to main documentation

## Troubleshooting

### "kubectl: command not found"
Install kubectl or ensure it's in your PATH.

### "Cannot connect to cluster"
Check kubeconfig: `export KUBECONFIG=talos/kubeconfig`

### "Permission denied"
Make scripts executable: `chmod +x scripts/*.sh`

### "talosctl not found"
Install talosctl or the script will skip Talos-specific info.

---

**Last Updated**: 2025-11-20
