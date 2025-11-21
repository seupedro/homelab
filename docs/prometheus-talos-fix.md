# Prometheus on Talos Linux - Permission Issue Fix

## Problem Summary

When deploying kube-prometheus-stack (v68.5.0) on a Talos Linux single-node Kubernetes cluster with `local-path-provisioner`, Prometheus was crash looping with this error:

```
level=error component=activeQueryTracker msg="Error opening query log file" file=/prometheus/queries.active err="open /prometheus/queries.active: permission denied"
panic: Unable to create mmap-ed active query log
```

## Root Cause

The issue is caused by a complex interaction between:

1. **Prometheus Active Query Tracker**: Prometheus v2.55.1 (and v3.x) uses an active query tracker that creates an mmap-ed file at `/prometheus/queries.active`
2. **Prometheus Operator Security Defaults**: The operator sets `readOnlyRootFilesystem: true` by default for security
3. **Talos Linux + local-path-provisioner**: Permission handling differs from standard Linux distributions
4. **subPath Mount Behavior**: The PVC is mounted with `subPath: prometheus-db` which has special permission semantics

Even when explicitly setting:
- `readOnlyRootFilesystem: false` on the prometheus container
- `fsGroup: 2000` for volume ownership
- Init containers to set `chmod 777` and `chown 1000:2000`
- Proper PVC binding and RW mount

The issue persisted because **Talos Linux handles filesystem permissions differently**, and the combination of security contexts prevented the non-root prometheus user from writing to the volume-mounted directory.

## Solution

Run Prometheus as root user (UID 0). While not ideal for production environments, this is acceptable for homelab deployments and solves the permission issue completely.

### Configuration Change

In `/home/seupedro/homelab/k8s/monitoring/prometheus-values.yaml`:

```yaml
prometheus:
  prometheusSpec:
    # Security context for Talos Linux compatibility
    # IMPORTANT: Running as root (runAsUser: 0) is required to fix permission issues
    # with the Prometheus query tracker on Talos Linux + local-path-provisioner
    securityContext:
      runAsUser: 0
      runAsNonRoot: false
      fsGroup: 0
```

### Deployment

```bash
cd /home/seupedro/homelab/k8s/monitoring

# Install/upgrade kube-prometheus-stack
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --version 68.5.0 \
  --values prometheus-values.yaml

# Verify deployment
kubectl get pods -n monitoring
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c prometheus
```

## Verification

After applying the fix, Prometheus should start successfully:

```bash
# Check pod status (should be Running)
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Check logs (should see "Server is ready to receive web requests")
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c prometheus --tail=20

# Verify metrics collection
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- \
  wget -q -O- http://localhost:9090/api/v1/status/config | jq .
```

## Alternative Solutions (Not Used)

These approaches were attempted but did not resolve the issue on Talos Linux:

1. ❌ **Disable read-only root filesystem**: Set `containers[].securityContext.readOnlyRootFilesystem: false` - didn't work
2. ❌ **Init containers to fix permissions**: Used init containers with root to chmod/chown - didn't work
3. ❌ **Disable query tracker**: Attempted to add `--query.max-concurrency=0` flag - operator overrode changes
4. ❌ **Mount emptyDir volumes**: Tried mounting writable emptyDir at various paths - didn't solve the core issue
5. ❌ **Patch StatefulSet directly**: Changes were reverted by Prometheus Operator reconciliation

## Security Considerations

**For Homelab Use**: Running Prometheus as root is acceptable since:
- Single-node cluster with trusted workloads
- No multi-tenant environment
- Physical security of infrastructure
- Monitoring is isolated in its own namespace

**For Production Use**: Consider these alternatives:
- Use a different storage class that handles permissions better (e.g., Longhorn, Rook-Ceph)
- Deploy on a non-Talos Kubernetes distribution
- Use Prometheus with alternative storage backends
- Implement custom admission controllers for volume permissions
- Use managed Prometheus services (e.g., Amazon Managed Prometheus, Google Cloud Monitoring)

## Files Modified

- `/home/seupedro/homelab/k8s/monitoring/prometheus-values.yaml` - Updated security context to run as root

## Related Issues

- Kubernetes subPath + fsGroup permission issues: https://github.com/kubernetes/kubernetes/issues/67014
- Prometheus Operator security contexts: https://github.com/prometheus-operator/prometheus-operator/issues/3720
- Talos Linux storage considerations: https://www.talos.dev/v1.5/kubernetes-guides/configuration/storage/

## Date

Fixed: 2025-11-20

## Cluster Information

- Kubernetes: v1.34.1
- Talos Linux: v1.9.0+ (kernel 6.12.57-talos)
- Storage Class: local-path-provisioner
- Chart: prometheus-community/kube-prometheus-stack v68.5.0
- Prometheus Version: v2.55.1
