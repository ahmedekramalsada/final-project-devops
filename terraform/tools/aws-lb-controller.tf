# =============================================================================
# IAM Role for AWS Load Balancer Controller
# =============================================================================

# Check if IAM Policy already exists
data "aws_iam_policy" "lb_controller_existing" {
  count = var.create_lb_controller_iam ? 0 : 1
  name  = "${var.project_name}-lb-controller"
}

# Check if IAM Role already exists
data "aws_iam_role" "lb_controller_existing" {
  count = var.create_lb_controller_iam ? 0 : 1
  name  = "${var.project_name}-lb-controller"
}

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
  }
}

# Create IAM Policy (only if it doesn't exist)
resource "aws_iam_policy" "lb_controller" {
  count = var.create_lb_controller_iam ? 1 : 0

  name        = "${var.project_name}-lb-controller"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam_policy.json")
}

# Create IAM Role (only if it doesn't exist)
resource "aws_iam_role" "lb_controller" {
  count = var.create_lb_controller_iam ? 1 : 0

  name               = "${var.project_name}-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume.json
}

# Attach policy to role (only if creating new resources)
resource "aws_iam_role_policy_attachment" "lb_controller" {
  count = var.create_lb_controller_iam ? 1 : 0

  role       = aws_iam_role.lb_controller[0].name
  policy_arn = aws_iam_policy.lb_controller[0].arn
}

# Use existing IAM Role ARN for the Helm chart
locals {
  lb_controller_role_arn = var.create_lb_controller_iam ? aws_iam_role.lb_controller[0].arn : data.aws_iam_role.lb_controller_existing[0].arn
}
