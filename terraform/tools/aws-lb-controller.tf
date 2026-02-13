# =============================================================================
# IAM Role for AWS Load Balancer Controller (IRSA)
# =============================================================================

# Get EKS cluster info for OIDC configuration
data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.infrastructure.outputs.cluster_name
}

# OIDC Provider configuration
# Extract the OIDC provider URL without the https:// prefix for the trust policy
locals {
  # OIDC issuer URL from EKS cluster: https://oidc.eks.region.amazonaws.com/id/XXXXX
  # We need: oidc.eks.region.amazonaws.com/id/XXXXX (without https://)
  oidc_provider_url = replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
  oidc_provider_arn = data.terraform_remote_state.infrastructure.outputs.oidc_provider_arn

  # Standardized naming
  lb_controller_role_name = "${var.project_name}-lb-controller"
  lb_controller_sa_name   = "aws-load-balancer-controller"
}

# =============================================================================
# Trust Policy Document for OIDC (IRSA)
# This allows the Kubernetes service account to assume this IAM role
# =============================================================================
data "aws_iam_policy_document" "lb_controller_assume" {
  statement {
    sid     = "AllowAssumeRoleWithWebIdentity"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:${local.lb_controller_sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# =============================================================================
# IAM Policy for AWS Load Balancer Controller
# Using the official AWS managed policy as reference
# =============================================================================
resource "aws_iam_policy" "lb_controller" {
  name        = "${var.project_name}-lb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller - manages ALBs and NLBs"
  policy      = file("${path.module}/iam_policy.json")

  tags = {
    Name    = "${var.project_name}-lb-controller-policy"
    Service = "aws-load-balancer-controller"
  }
}

# =============================================================================
# IAM Role for the controller
# =============================================================================
resource "aws_iam_role" "lb_controller" {
  name                  = local.lb_controller_role_name
  assume_role_policy    = data.aws_iam_policy_document.lb_controller_assume.json
  force_detach_policies = true

  # Increase session duration for better reliability
  max_session_duration = 3600

  tags = {
    Name    = local.lb_controller_role_name
    Service = "aws-load-balancer-controller"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

# =============================================================================
# Kubernetes Service Account with IAM Role Annotation
# CRITICAL: Create the SA before Helm deployment with proper annotation
# This ensures the annotation is present before the controller pods start
# =============================================================================
resource "kubernetes_service_account" "lb_controller" {
  metadata {
    name      = local.lb_controller_sa_name
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lb_controller.arn
    }

    labels = {
      "app.kubernetes.io/name"    = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
  }

  # Handle existing service accounts gracefully
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [metadata[0].labels]  # Ignore label changes from Helm
  }

  # Wait for IAM role propagation
  depends_on = [
    aws_iam_role_policy_attachment.lb_controller,
    time_sleep.wait_for_eks
  ]
}

# Wait for IAM role propagation to IAM backend (eventual consistency)
resource "time_sleep" "wait_iam_propagation" {
  create_duration = "30s"
  depends_on      = [kubernetes_service_account.lb_controller]
}

# Output the role ARN for reference
locals {
  lb_controller_role_arn = aws_iam_role.lb_controller.arn
}
