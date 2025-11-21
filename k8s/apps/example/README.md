# Example Application

This is an example deployment demonstrating the automated deployment pipeline.

## Application Details

- **Name**: example
- **Image**: nginx:alpine
- **URL**: https://example.pane.run
- **Replicas**: 2

## Deployment Methods

### Method 1: Using the deployment script

```bash
./scripts/deploy-app.sh \
  --name example \
  --subdomain example \
  --image nginx:alpine \
  --port 80 \
  --replicas 2
```

### Method 2: Applying manifests directly

```bash
kubectl apply -f k8s/apps/example/
```

### Method 3: Using GitHub Actions

1. **Automatic deployment**: Push changes to this directory to main branch
2. **Manual deployment**: Go to Actions → Deploy Application → Run workflow

## Verify Deployment

Check deployment status:
```bash
kubectl get all -n example
```

View logs:
```bash
kubectl logs -n example -l app=example --tail=100 -f
```

Access the application:
```bash
curl https://example.pane.run
```

## Rollback

If you need to rollback to a previous version:

```bash
# View rollout history
kubectl rollout history deployment/example -n example

# Rollback to previous revision
kubectl rollout undo deployment/example -n example

# Rollback to specific revision
kubectl rollout undo deployment/example -n example --to-revision=2
```

Or use GitHub Actions → Rollback Application workflow.

## Cleanup

To delete the application:

```bash
kubectl delete namespace example
```
