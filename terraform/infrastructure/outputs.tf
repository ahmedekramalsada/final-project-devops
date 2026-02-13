# =============================================================================
# EKS Cluster Outputs
# =============================================================================
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded CA data for cluster authentication"
  value       = module.eks.cluster_certificate_authority_data
}

# =============================================================================
# OIDC Provider Outputs (for IRSA)
# =============================================================================
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://)"
  value       = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
}

# =============================================================================
# VPC Outputs
# =============================================================================
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

# =============================================================================
# Security Group Outputs
# =============================================================================
output "node_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = module.eks.node_security_group_id
}

output "cluster_security_group_id" {
  description = "Security group ID for EKS cluster"
  value       = module.eks.cluster_security_group_id
}

# =============================================================================
# Network Load Balancer Outputs
# =============================================================================
output "nlb_target_group_arn" {
  description = "ARN of the NLB target group for NGINX"
  value       = aws_lb_target_group.nginx.arn
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.main.dns_name
}

output "nlb_zone_id" {
  description = "Route 53 zone ID for the NLB"
  value       = aws_lb.main.zone_id
}

# =============================================================================
# API Gateway Outputs
# =============================================================================
output "api_gateway_endpoint" {
  description = "API Gateway invoke URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

# =============================================================================
# Cognito Outputs
# =============================================================================
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.main.id
}

output "cognito_domain" {
  description = "Cognito domain URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}
