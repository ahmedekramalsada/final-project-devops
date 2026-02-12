#!/bin/bash
# Pre-destroy cleanup script

set +e

echo "Cleaning up Kubernetes resources..."

aws eks update-kubeconfig --name devops-cluster --region us-east-1 || true

kubectl delete application devops-app -n argocd --ignore-not-found=true || true
kubectl delete ingress --all-namespaces --all --timeout=60s || true
kubectl delete targetgroupbindings -A --all --timeout=60s || true
kubectl delete secret app-secrets -n default --ignore-not-found=true || true
kubectl delete secret nexus-registry-secret -n default --ignore-not-found=true || true
kubectl delete namespace tooling --ignore-not-found=true --timeout=60s || true
kubectl delete namespace argocd --ignore-not-found=true --timeout=60s || true
kubectl delete namespace ingress-nginx --ignore-not-found=true --timeout=60s || true

echo "Cleanup complete!"
