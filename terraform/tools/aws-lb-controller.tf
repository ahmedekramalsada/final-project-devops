# =============================================================================
# IAM Role for AWS Load Balancer Controller
# =============================================================================

# Get EKS cluster info for OIDC
data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.infrastructure.outputs.cluster_name
}

# Extract OIDC provider URL correctly
locals {
  # OIDC issuer URL from EKS cluster: https://oidc.eks.region.amazonaws.com/id/XXXXX
  # We need: oidc.eks.region.amazonaws.com/id/XXXXX (without https://)
  oidc_provider_url = replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
  oidc_provider_arn = data.terraform_remote_state.infrastructure.outputs.oidc_provider_arn
}

# Trust policy document for OIDC
data "aws_iam_policy_document" "lb_controller_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Create IAM Policy
resource "aws_iam_policy" "lb_controller" {
  name        = "${var.project_name}-lb-controller-v3"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam_policy.json")
}

# Create IAM Role
resource "aws_iam_role" "lb_controller" {
  name                  = "${var.project_name}-lb-controller-v3"
  assume_role_policy    = data.aws_iam_policy_document.lb_controller_assume.json
  force_detach_policies = true
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

locals {
  lb_controller_role_arn = aws_iam_role.lb_controller.arn
}
