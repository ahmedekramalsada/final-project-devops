# DevOps Final Project Documentation

## Project Overview

This document contains all the important information for setting up and managing your DevOps intern project infrastructure.

### Infrastructure Components

| Component | Location | Status |
|-----------|----------|--------|
| Vault & Nexus | EC2 | Already running |
| S3 Bucket | AWS | Already created (for Terraform state) |
| Azure DevOps | Cloud | For CI/CD pipelines |
| MongoDB | External | Connect only (not deployed) |
| Datadog | External | Connect only (not deployed) |
| EKS Cluster | AWS | To be deployed |
| API Gateway | AWS | To be deployed |
| Cognito | AWS | To be deployed |

### Project Pipelines

1. **Infrastructure Pipeline**: VPC, EKS, NLB, API Gateway, Cognito
2. **Tools Pipeline**: NGINX Ingress, ArgoCD, SonarQube, AWS LB Controller
3. **Application Pipeline**: Build, scan, push to Nexus, deploy via ArgoCD

---

## Issues Fixed During Setup

### 1. DynamoDB State Locking

- **Issue**: User didn't want DynamoDB, only simple S3 backend
- **Solution**: Removed DynamoDB references from `versions.tf` files

### 2. S3 Bucket Configuration

You need to edit THREE files with your S3 bucket name:

- `terraform/infrastructure/versions.tf`
- `terraform/tools/versions.tf`
- `terraform/tools/remote-state.tf`

Replace `YOUR-S3-BUCKET-NAME` with your actual bucket name.

### 3. AWS Service Connection Type

- **Error**: "service connection of type AWSServiceEndpoint expects AWS for Terraform"
- **Solution**: Create "AWS for Terraform" service connection (not regular AWS)
- **Connection Name**: `aws-terraform-connection`

### 4. Terraform Init Missing backendServiceAWS

- **Error**: "Input required: backendServiceAWS"
- **Solution**: Add backend configuration to Terraform Init task:

```yaml
backendServiceAWS: 'aws-terraform-connection'
backendAWSBucketName: 'YOUR-S3-BUCKET-NAME'
backendAWSKey: 'devops-project/infrastructure.tfstate'
backendAWSRegion: 'us-east-1'
```

### 5. Cognito Resource Errors

**Errors encountered:**
- `aws_cognito_user` - Invalid argument "email"
- `aws_cognito_user_pool_password` - Resource type not supported
- `aws_cognito_user_pool_user` - Resource type not supported

**Final Fix for `cognito.tf`** (simplified version without auto-creating user):

```hcl
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-user-pool"
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  admin_create_user_config {
    allow_admin_create_user_only = false
  }
}

resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.main.id
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
  allowed_oauth_flows                  = ["implicit", "code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  callback_urls                        = ["https://localhost/callback"]
  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}
```

### 6. IRSA (IAM Roles for Service Accounts) Error - CRITICAL FIX

**Error:**
```
WebIdentityErr: failed to retrieve credentials
caused by: AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**Root Causes:**
1. Incorrect Helm annotation format for service account
2. Missing IAM propagation wait time
3. TargetGroupBinding created before webhook ready

**Solution Applied:**

1. **Pre-create Service Account with Annotation:**
```hcl
resource "kubernetes_service_account" "lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lb_controller.arn
    }
  }
}
```

2. **Tell Helm NOT to Create Service Account:**
```hcl
set {
  name  = "serviceAccount.create"
  value = "false"
}
set {
  name  = "serviceAccount.name"
  value = "aws-load-balancer-controller"
}
```

3. **Add IAM Propagation Wait:**
```hcl
resource "time_sleep" "wait_iam_propagation" {
  create_duration = "30s"
  depends_on      = [kubernetes_service_account.lb_controller]
}
```

See `docs/IRSA-TROUBLESHOOTING.md` for detailed verification steps.

---

## Creating Cognito User Manually

After the infrastructure pipeline completes, you need to create an admin user:

### Step 1: Get User Pool ID

```bash
aws cognito-idp list-user-pools --max-results 10 --region us-east-1
```

### Step 2: Create User

```bash
aws cognito-idp admin-create-user \
  --user-pool-id <USER_POOL_ID> \
  --username admin@devops.com \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS \
  --region us-east-1
```

### Step 3: Set Permanent Password

```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id <USER_POOL_ID> \
  --username admin@devops.com \
  --password "Admin@123!" \
  --permanent \
  --region us-east-1
```

---

## Understanding AWS Cognito

### What is Cognito?

AWS Cognito is an authentication service that protects all your services:
- Application
- ArgoCD
- SonarQube

### Authentication Flow

```
User → Cognito Login → JWT Token → API Gateway validates token → Access granted
```

### How It Works

1. Users authenticate with Cognito (username/password)
2. Cognito returns a JWT (JSON Web Token)
3. User includes token in HTTP header: `Authorization: <token>`
4. API Gateway validates the token
5. Access is granted to the requested service

---

## Accessing Services After Setup

### Step 1: Get Cognito Token

```bash
# Get token using AWS CLI
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <USER_POOL_CLIENT_ID> \
  --auth-parameters USERNAME=admin@devops.com,PASSWORD="Admin@123!" \
  --region us-east-1
```

### Step 2: Use Token to Access Services

```bash
# Extract the AccessToken from the response
TOKEN="<your-access-token>"

# Access your application through API Gateway
curl -H "Authorization: $TOKEN" https://<api-gateway-url>/api

# Access ArgoCD
curl -H "Authorization: $TOKEN" https://<api-gateway-url>/argocd

# Access SonarQube
curl -H "Authorization: $TOKEN" https://<api-gateway-url>/sonarqube
```

### Step 3: Browser Access

For browser-based access, you can use the Cognito Hosted UI:

1. Navigate to: `https://<your-domain>.auth.us-east-1.amazoncognito.com/login?response_type=token&client_id=<CLIENT_ID>&redirect_uri=https://localhost/callback`
2. Login with your credentials
3. The redirect URL will contain your tokens in the URL fragment

---

## Important Endpoints

After your infrastructure is deployed, note these endpoints:

| Service | Endpoint |
|---------|----------|
| API Gateway URL | `https://<api-id>.execute-api.us-east-1.amazonaws.com` |
| Cognito Domain | `https://<project-name>-auth.auth.us-east-1.amazoncognito.com` |
| ArgoCD | `https://<api-gateway-url>/argocd` |
| SonarQube | `https://<api-gateway-url>/sonarqube` |
| Application | `https://<api-gateway-url>/api` |

---

## Troubleshooting

### Common Issues

1. **Pipeline fails with authentication error**
   - Verify AWS service connection is "AWS for Terraform" type
   - Check that `aws-terraform-connection` exists in Azure DevOps

2. **Terraform state lock issues**
   - Ensure S3 bucket exists and has proper permissions
   - Verify bucket name matches in all configuration files

3. **Cognito user creation fails**
   - Verify User Pool ID is correct
   - Ensure password meets policy requirements (8+ chars, upper, lower, number, symbol)

4. **Token validation fails**
   - Check token hasn't expired (default: 1 hour)
   - Verify correct Client ID is being used
   - Ensure token is in correct format for Authorization header

5. **IRSA / WebIdentity error**
   - See `docs/IRSA-TROUBLESHOOTING.md` for detailed steps
   - Verify service account has correct annotation
   - Check IAM role trust policy matches OIDC provider

6. **TargetGroupBinding fails to create**
   - Ensure AWS LB Controller pod is running
   - Verify service account can assume IAM role
   - Check controller logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`

---

## Quick Reference Commands

```bash
# List all User Pools
aws cognito-idp list-user-pools --max-results 10 --region us-east-1

# List User Pool Clients
aws cognito-idp list-user-pool-clients --user-pool-id <POOL_ID> --region us-east-1

# List Users in Pool
aws cognito-idp list-users --user-pool-id <POOL_ID> --region us-east-1

# Delete User
aws cognito-idp admin-delete-user --user-pool-id <POOL_ID> --username admin@devops.com --region us-east-1

# Refresh Token
aws cognito-idp initiate-auth --auth-flow REFRESH_TOKEN_AUTH --client-id <CLIENT_ID> --auth-parameters REFRESH_TOKEN=<REFRESH_TOKEN> --region us-east-1

# Check AWS LB Controller Service Account
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml

# Check AWS LB Controller Logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

# Check TargetGroupBindings
kubectl get targetgroupbindings -A
```

---

## Deployment Order

1. **First**: Run Infrastructure Pipeline
   - Creates VPC, EKS, NLB, API Gateway, Cognito

2. **Second**: Create Cognito User (manual)
   - See instructions above

3. **Third**: Run Tools Pipeline
   - Deploys AWS LB Controller, NGINX, ArgoCD, SonarQube
   - Creates TargetGroupBinding for NLB

4. **Fourth**: Run Application Pipeline
   - Builds and deploys the sample application

---

*Document created for DevOps Final Project - Internship Program*
