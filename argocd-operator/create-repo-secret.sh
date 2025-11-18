#!/bin/bash
set -e

echo "This script creates a sealed ArgoCD repository secret for SSH access"
echo "================================================================"
echo ""

# Check if SSH key exists
SSH_KEY_PATH="${1:-$HOME/.ssh/id_rsa}"

if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "SSH private key not found at: $SSH_KEY_PATH"
  echo ""
  echo "To generate a new SSH key:"
  echo "  ssh-keygen -t ed25519 -C 'argocd@homelab' -f ~/.ssh/argocd_homelab"
  echo ""
  echo "Then add the public key to GitHub:"
  echo "  cat ~/.ssh/argocd_homelab.pub"
  echo "  Go to: https://github.com/seupedro/homelab/settings/keys"
  echo ""
  echo "Run this script again with:"
  echo "  ./argocd-operator/create-repo-secret.sh ~/.ssh/argocd_homelab"
  exit 1
fi

echo "Using SSH key: $SSH_KEY_PATH"
echo ""

# Create the repository secret
kubectl create secret generic argocd-repo-homelab \
  --namespace=argocd \
  --from-literal=type=git \
  --from-literal=url=git@github.com:seupedro/homelab.git \
  --from-file=sshPrivateKey="$SSH_KEY_PATH" \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > argocd-operator/argocd-repo-secret-sealed.yaml

echo "✓ Created sealed secret: argocd-operator/argocd-repo-secret-sealed.yaml"
echo ""
echo "Next steps:"
echo "1. Review the sealed secret file"
echo "2. Commit and push: git add argocd-operator/argocd-repo-secret-sealed.yaml && git commit -m 'Add ArgoCD repository secret' && git push"
echo "3. Apply to cluster: kubectl apply -f argocd-operator/argocd-repo-secret-sealed.yaml"
echo "4. Apply ApplicationSet: kubectl apply -f argocd-operator/applicationset.yaml"
