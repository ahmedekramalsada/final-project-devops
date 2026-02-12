output "api_gateway_url" {
  value = data.terraform_remote_state.infrastructure.outputs.api_gateway_endpoint
}

output "argocd_url" {
  value = "${data.terraform_remote_state.infrastructure.outputs.api_gateway_endpoint}argocd"
}

output "sonarqube_url" {
  value = "${data.terraform_remote_state.infrastructure.outputs.api_gateway_endpoint}sonarqube"
}

output "cognito_client_id" {
  value = data.terraform_remote_state.infrastructure.outputs.cognito_client_id
}

output "get_token_command" {
  value = "aws cognito-idp initiate-auth --client-id ${data.terraform_remote_state.infrastructure.outputs.cognito_client_id} --auth-flow USER_PASSWORD_AUTH --auth-parameters USERNAME=admin@devops.com,PASSWORD='Admin@123!' --region ${var.aws_region}"
}

output "argocd_password_command" {
  value = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
}
