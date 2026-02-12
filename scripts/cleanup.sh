#!/bin/bash
# Pre-destroy cleanup script for DevOps Final Project
# Run this before destroying Terraform infrastructure

set +e

echo "=========================================="
echo "DevOps Project Cleanup Script"
echo "=========================================="

# Update kubeconfig
echo "[1/7] Updating kubeconfig..."
aws eks update-kubeconfig --name devops-cluster --region us-east-1 || {
    echo "Warning: Could not update kubeconfig. Cluster may not exist."
}

# Delete ArgoCD application first
echo "[2/7] Deleting ArgoCD application..."
kubectl delete application devops-app -n argocd --ignore-not-found=true --timeout=60s || true

# Delete all ingresses
echo "[3/7] Deleting all ingresses..."
kubectl delete ingress --all-namespaces --all --timeout=60s || true

# Delete TargetGroupBindings (required before destroying NLB)
echo "[4/7] Deleting TargetGroupBindings..."
kubectl delete targetgroupbindings -A --all --timeout=60s || true

# Delete secrets
echo "[5/7] Deleting Kubernetes secrets..."
kubectl delete secret app-secrets -n default --ignore-not-found=true || true
kubectl delete secret nexus-registry-secret -n default --ignore-not-found=true || true

# Delete namespaces (this will delete all resources in them)
echo "[6/7] Deleting namespaces..."
kubectl delete namespace tooling --ignore-not-found=true --timeout=120s || true
kubectl delete namespace argocd --ignore-not-found=true --timeout=120s || true
kubectl delete namespace ingress-nginx --ignore-not-found=true --timeout=120s || true

# Verify cleanup
echo "[7/7] Verifying cleanup..."
echo ""
echo "Remaining namespaces:"
kubectl get namespaces
echo ""
echo "Remaining resources in default namespace:"
kubectl get all -n default

echo ""
echo "=========================================="
echo "Cleanup complete!"
echo "=========================================="
echo ""
echo "You can now run Terraform destroy safely."
