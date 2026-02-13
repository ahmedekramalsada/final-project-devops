# =============================================================================
# IAM Role for AWS Load Balancer Controller
# =============================================================================

data "aws_iam_policy_document" "lb_controller_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [data.terraform_remote_state.infrastructure.outputs.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.terraform_remote_state.infrastructure.outputs.oidc_provider_arn, "/^(.*provider/)/", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.terraform_remote_state.infrastructure.outputs.oidc_provider_arn, "/^(.*provider/)/", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Create IAM Policy
resource "aws_iam_policy" "lb_controller" {
  name        = "${var.project_name}-lb-controller"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam_policy.json")
}

# Create IAM Role with correct OIDC trust policy
resource "aws_iam_role" "lb_controller" {
  name                  = "${var.project_name}-lb-controller"
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
