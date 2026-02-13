# AWS Load Balancer Controller IRSA Troubleshooting Guide

## The Problem

The error you encountered:
```
WebIdentityErr: failed to retrieve credentials
caused by: AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

This occurs when the AWS Load Balancer Controller cannot assume its IAM role via IRSA (IAM Roles for Service Accounts).

## Root Causes Identified

### 1. Incorrect Service Account Annotation Method

**Before (Broken):**
```hcl
set {
  name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  value = local.lb_controller_role_arn
}
```

This Helm `set` syntax with escaped dots doesn't reliably set nested map keys.

**After (Fixed):**
Create the service account separately with proper annotation:
```hcl
resource "kubernetes_service_account" "lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lb_controller.arn
    }
  }
}
```

Then tell Helm NOT to create the service account:
```hcl
set {
  name  = "serviceAccount.create"
  value = "false"
}
set {
  name  = "serviceAccount.name"
  value = "aws-load-balancer-controller"
}
```

### 2. Missing Timing for IAM Propagation

AWS IAM is eventually consistent. The role and trust policy must be fully propagated before the controller starts.

**Fix:** Added explicit wait times:
```hcl
resource "time_sleep" "wait_iam_propagation" {
  create_duration = "30s"
  depends_on      = [kubernetes_service_account.lb_controller]
}
```

### 3. TargetGroupBinding Created Too Early

The TargetGroupBinding webhook wasn't ready when the resource was created.

**Fix:** Added verification step and proper dependencies:
```hcl
resource "null_resource" "verify_lb_controller" {
  provisioner "local-exec" {
    command = "kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s"
  }
  depends_on = [helm_release.aws_load_balancer_controller]
}
```

## Verification Steps

### 1. Check Service Account Annotation
```bash
kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml
```

You should see:
```yaml
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/devops-final-lb-controller
```

### 2. Check OIDC Provider Exists
```bash
aws iam get-open-id-connect-provider --open-id-connect-provider-arn $(aws eks describe-cluster --name devops-cluster --query 'cluster.identity.oidc.issuer' --output text | sed 's|https://|arn:aws:iam::ACCOUNT_ID:oidc-provider/|')
```

### 3. Verify IAM Role Trust Policy
```bash
aws iam get-role --role-name devops-final-lb-controller --query 'Role.AssumeRolePolicyDocument'
```

Should show:
```json
{
  "Statement": [{
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc.eks.region.amazonaws.com/id/XXX:aud": "sts.amazonaws.com",
        "oidc.eks.region.amazonaws.com/id/XXX:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
      }
    },
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.region.amazonaws.com/id/XXX"
    }
  }]
}
```

### 4. Check Controller Pod Logs
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

Look for successful credential loading:
```
"level":"info","msg":"successfully authenticated with IRSA"
```

### 5. Test TargetGroupBinding Creation
```bash
kubectl apply -f - <<EOF
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: test-tgb
  namespace: default
spec:
  serviceRef:
    name: test-service
    port: 80
  targetGroupARN: arn:aws:elasticloadbalancing:region:account:targetgroup/tg-name/id
  targetType: ip
EOF
```

## Common Issues and Solutions

### Issue: "access denied" when creating TargetGroupBinding
**Solution:** Verify the IAM policy has all required permissions (see iam_policy.json).

### Issue: "webhook not ready"
**Solution:** Wait longer. The webhook service needs time to register.
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Issue: "cannot get target group IP address type"
**Solution:** This means IRSA isn't working. The controller can't query AWS ELB APIs.
Check service account annotation and IAM role trust policy.

## Best Practices Applied

1. **Pre-create Service Accounts** with annotations before Helm deployment
2. **Add explicit wait times** for IAM propagation
3. **Use proper dependency chains** with `depends_on`
4. **Verify resources are ready** before proceeding
5. **Include region and VPC configuration** in Helm values
6. **Use kubectl provider timeouts** for long-running resources

## Files Modified

1. `terraform/tools/aws-lb-controller.tf` - Fixed IRSA configuration
2. `terraform/tools/helm-releases.tf` - Fixed Helm values and timing
3. `terraform/tools/k8s-resources.tf` - Added verification and proper dependencies
4. `terraform/tools/providers.tf` - Added proper provider configuration
5. `terraform/tools/versions.tf` - Added null provider
6. `terraform/infrastructure/outputs.tf` - Added missing outputs
7. `terraform/infrastructure/eks.tf` - Added IRSA enable flag
8. `pipelines/02-tools.yml` - Added kubectl installation and verification
