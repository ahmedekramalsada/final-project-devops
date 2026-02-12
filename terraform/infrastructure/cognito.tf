# ==============================================================================
# Cognito User Pool - Authentication for API Gateway
# ==============================================================================

# User Pool
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-user-pool"

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Email as username
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Allow admin to create users
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  tags = {
    Name = "${var.project_name}-user-pool"
  }
}

# User Pool Client
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Authentication flows
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  # OAuth configuration
  allowed_oauth_flows                  = ["implicit", "code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  callback_urls                        = ["https://localhost/callback"]
  logout_urls                          = ["https://localhost/logout"]
  supported_identity_providers         = ["COGNITO"]

  # Token validity
  access_token_validity  = 1  # hours
  id_token_validity      = 1  # hours
  refresh_token_validity = 30 # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  prevent_user_existence_errors = "ENABLED"
}

# User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Admin User - Create with temporary password
resource "aws_cognito_user_pool_user" "admin" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = var.cognito_admin_email

  attributes = {
    email          = var.cognito_admin_email
    email_verified = "true"
  }

  message_action     = "SUPPRESS"
  temporary_password = var.cognito_admin_password
}

# Set permanent password using null_resource and AWS CLI
resource "null_resource" "set_admin_password" {
  depends_on = [aws_cognito_user_pool_user.admin]

  provisioner "local-exec" {
    command = <<-EOT
      aws cognito-idp admin-set-user-password \
        --user-pool-id ${aws_cognito_user_pool.main.id} \
        --username ${var.cognito_admin_email} \
        --password '${var.cognito_admin_password}' \
        --permanent \
        --region ${var.aws_region}
    EOT
  }

  # Only run on create, not on destroy
  triggers = {
    user_pool_id = aws_cognito_user_pool.main.id
    username     = var.cognito_admin_email
  }
}
 