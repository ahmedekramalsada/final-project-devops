# =============================================================================
# AWS Provider Configuration
# =============================================================================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

# =============================================================================
# Kubernetes Provider Configuration
# Uses EKS authentication via AWS CLI
# =============================================================================
provider "kubernetes" {
  host                   = data.terraform_remote_state.infrastructure.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infrastructure.outputs.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.infrastructure.outputs.cluster_name]
  }
}

# =============================================================================
# Helm Provider Configuration
# For deploying Kubernetes charts
# =============================================================================
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infrastructure.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infrastructure.outputs.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.infrastructure.outputs.cluster_name]
    }
  }
}

# =============================================================================
# Vault Provider Configuration
# For fetching secrets from HashiCorp Vault
# =============================================================================
provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}

# =============================================================================
# Kubectl Provider Configuration
# For applying raw Kubernetes manifests
# =============================================================================
provider "kubectl" {
  host                   = data.terraform_remote_state.infrastructure.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infrastructure.outputs.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.infrastructure.outputs.cluster_name]
  }
}
