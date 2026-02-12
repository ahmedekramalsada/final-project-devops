resource "aws_apigatewayv2_api" "main" {
  name          = var.api_gateway_name
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
  }
}

resource "aws_apigatewayv2_vpc_link" "eks" {
  name               = "${var.project_name}-vpc-link"
  security_group_ids = [module.eks.cluster_security_group_id]
  subnet_ids         = concat(module.vpc.public_subnets, module.vpc.private_subnets)
}

resource "aws_apigatewayv2_integration" "nlb" {
  api_id               = aws_apigatewayv2_api.main.id
  integration_type     = "HTTP_PROXY"
  integration_method   = "ANY"
  integration_uri      = aws_lb_listener.http.arn
  connection_type      = "VPC_LINK"
  connection_id        = aws_apigatewayv2_vpc_link.eks.id
  timeout_milliseconds = 30000
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  name             = "cognito-authorizer"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.main.id]
    issuer   = "https://${aws_cognito_user_pool.main.endpoint}"
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

# Routes
resource "aws_apigatewayv2_route" "default" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "$default"
  target             = "integrations/${aws_apigatewayv2_integration.nlb.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "argocd" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "ANY /argocd/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.nlb.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "argocd_root" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "ANY /argocd"
  target             = "integrations/${aws_apigatewayv2_integration.nlb.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "sonarqube" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "ANY /sonarqube/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.nlb.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "sonarqube_root" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "ANY /sonarqube"
  target             = "integrations/${aws_apigatewayv2_integration.nlb.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}
