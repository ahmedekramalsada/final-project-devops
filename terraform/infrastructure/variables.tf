variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "devops-final"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vault_address" {
  description = "Your Vault server URL (e.g., http://1.2.3.4:8200)"
  type        = string
}

variable "vault_token" {
  description = "Vault token"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "devops-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "EC2 instance types for nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum nodes"
  type        = number
  default     = 4
}

variable "node_desired_size" {
  description = "Desired nodes"
  type        = number
  default     = 2
}

variable "api_gateway_name" {
  description = "API Gateway name"
  type        = string
  default     = "devops-api"
}

variable "cognito_admin_email" {
  description = "Admin email for Cognito"
  type        = string
  default     = "admin@devops.com"
}

variable "cognito_admin_password" {
  description = "Admin password"
  type        = string
  default     = "Admin@123!"
  sensitive   = true
}
