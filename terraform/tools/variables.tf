variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "devops-final"
}

variable "vault_address" {
  type = string
}

variable "vault_token" {
  type      = string
  sensitive = true
}

variable "nexus_url" {
  description = "Your Nexus server URL (without port)"
  type        = string
}

variable "nexus_docker_port" {
  description = "Nexus Docker registry port"
  type        = number
  default     = 8082
}

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD"
  type        = string
}

variable "create_lb_controller_iam" {
  description = "Whether to create new IAM resources for LB Controller (set to false if they already exist)"
  type        = bool
  default     = true
}
