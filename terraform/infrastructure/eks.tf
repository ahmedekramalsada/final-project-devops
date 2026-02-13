# =============================================================================
# EKS Cluster Configuration
# =============================================================================

# KMS Key for EKS secrets encryption
resource "aws_kms_key" "eks" {
  description             = "EKS encryption key for secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-eks-key"
  }
}

# =============================================================================
# EKS Cluster Module
# =============================================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # Cluster endpoint access configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Enable OIDC provider for IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Cluster encryption configuration
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    workers = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      labels = {
        Environment = var.environment
      }

      tags = {
        Name = "${var.project_name}-worker"
      }
    }
  }

  # Cluster addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  tags = {
    Name = var.cluster_name
  }
}

# =============================================================================
# Security Group Rules for Node Groups
# =============================================================================
# Allow HTTP traffic to worker nodes
resource "aws_security_group_rule" "node_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.node_security_group_id
  description       = "Allow HTTP traffic"
}

# Allow HTTPS traffic to worker nodes
resource "aws_security_group_rule" "node_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.node_security_group_id
  description       = "Allow HTTPS traffic"
}

# Allow all traffic within the VPC for internal communication
resource "aws_security_group_rule" "node_internal" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = module.eks.node_security_group_id
  security_group_id        = module.eks.node_security_group_id
  description              = "Allow internal VPC traffic"
}

# =============================================================================
# Wait for EKS cluster to be fully ready
# =============================================================================
resource "time_sleep" "wait_eks" {
  create_duration = "60s"
  depends_on      = [module.eks]
}
