# Complete Step-by-Step Guide

This guide will walk you through the entire process of setting up and running the DevOps project.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Step 1: Configure S3 Bucket](#step-1-configure-s3-bucket)
3. [Step 2: Configure Vault](#step-2-configure-vault)
4. [Step 3: Configure Nexus](#step-3-configure-nexus)
5. [Step 4: Setup Azure DevOps](#step-4-setup-azure-devops)
6. [Step 5: Push Code to Git](#step-5-push-code-to-git)
7. [Step 6: Run Infrastructure Pipeline](#step-6-run-infrastructure-pipeline)
8. [Step 7: Run Tools Pipeline](#step-7-run-tools-pipeline)
9. [Step 8: Run Application Pipeline](#step-8-run-application-pipeline)
10. [Step 9: Access Services](#step-9-access-services)
11. [Step 10: Destroy Everything](#step-10-destroy-everything)

---

## 1. Prerequisites

### What You Need

| Requirement | Description |
|-------------|-------------|
| **AWS Account** | With permissions for VPC, EKS, IAM, API Gateway, Cognito |
| **Vault Server** | Running on EC2 (you already have this) |
| **Nexus Server** | Running on EC2 with Docker registry enabled on port 8082 |
| **S3 Bucket** | For Terraform state storage (already created) |
| **Azure DevOps** | Organization with project created |
| **GitHub Account** | For code repository |
| **MongoDB** | External MongoDB instance (connection string needed) |

---

## Step 1: Configure S3 Bucket

### 1.1 Edit versions.tf Files

You need to add your S3 bucket name in **THREE** places:

#### File 1: `terraform/infrastructure/versions.tf`

```hcl
backend "s3" {
  bucket = "YOUR-S3-BUCKET-NAME"     # <-- Replace with your bucket
  key    = "devops-project/infrastructure.tfstate"
  region = "us-east-1"
}
```

#### File 2: `terraform/tools/versions.tf`

```hcl
backend "s3" {
  bucket = "YOUR-S3-BUCKET-NAME"     # <-- Replace with your bucket
  key    = "devops-project/tools.tfstate"
  region = "us-east-1"
}
```

#### File 3: `terraform/tools/remote-state.tf`

```hcl
data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "YOUR-S3-BUCKET-NAME"     # <-- Replace with your bucket
    key    = "devops-project/infrastructure.tfstate"
    region = "us-east-1"
  }
}
```

### 1.2 Example

If your bucket name is `my-terraform-state-bucket`, it should look like:

```hcl
backend "s3" {
  bucket = "my-terraform-state-bucket"
  key    = "devops-project/infrastructure.tfstate"
  region = "us-east-1"
}
```

---

## Step 2: Configure Vault

### 2.1 SSH to Your Vault Server

```bash
ssh ec2-user@YOUR-VAULT-IP
```

### 2.2 Enable KV Secrets Engine (if not already)

```bash
vault secrets enable -path=kv kv-v2
```

### 2.3 Create App Secrets (MongoDB connection)

```bash
vault kv put kv/app \
    mongodb_uri="mongodb://USER:PASSWORD@MONGODB-HOST:27017/DATABASE"
```

**Replace:**
- `USER` - MongoDB username
- `PASSWORD` - MongoDB password  
- `MONGODB-HOST` - MongoDB server IP or hostname
- `DATABASE` - Database name

### 2.4 Create Nexus Secrets

```bash
vault kv put kv/nexus \
    username="admin" \
    password="YOUR-NEXUS-PASSWORD"
```

### 2.5 Verify Secrets

```bash
vault kv list kv/
vault kv get kv/app
vault kv get kv/nexus
```

### 2.6 Get Vault Token

You need your Vault token for Azure DevOps:

```bash
# If you have root token, use that
# Or create a new token:
vault token create -ttl=720h
```

**Write down:**
- Vault URL: `http://YOUR-VAULT-IP:8200`
- Vault Token: `hvs.xxxxxxxx`

---

## Step 3: Configure Nexus

### 3.1 Create Docker Repository

1. Open Nexus: `http://YOUR-NEXUS-IP:8081`
2. Login with admin credentials
3. Go to **Repository → Repositories**
4. Click **Create repository**
5. Select **docker (hosted)**
6. Configure:
   - Name: `docker-hosted`
   - HTTP Port: `8082`
   - Enable Docker V1: checked
7. Click **Create repository**

### 3.2 Test Docker Login

```bash
docker login YOUR-NEXUS-IP:8082
# Username: admin
# Password: YOUR-NEXUS-PASSWORD
```

---

## Step 4: Setup Azure DevOps

### 4.1 Create Project

1. Go to https://dev.azure.com
2. Click **New Project**
3. Name: `devops-final-project`
4. Click **Create**

### 4.2 Create Variable Group

1. Go to **Pipelines → Library**
2. Click **+ Variable group**
3. Name: `devops-config`
4. Add these variables:

| Variable Name | Value | Secret? |
|---------------|-------|---------|
| `vault-address` | `http://YOUR-VAULT-IP:8200` | No |
| `vault-token` | Your Vault token | **Yes** |
| `nexus-url` | `YOUR-NEXUS-IP` | No |
| `git-repo-url` | `https://github.com/USERNAME/REPO.git` | No |
| `git-token` | Your GitHub PAT | **Yes** |
| `git-repo` | `USERNAME/REPO` | No |

5. Click **Save**

### 4.3 Create Service Connections

#### AWS Service Connection

1. Go to **Project Settings → Service connections**
2. Click **New service connection**
3. Select **AWS**
4. Configure:
   - Connection name: `aws-service-connection`
   - Access Key ID: Your AWS access key
   - Secret Access Key: Your AWS secret key
5. Click **Save**

#### Nexus Service Connection

1. Click **New service connection**
2. Select **Docker Registry**
3. Configure:
   - Connection name: `nexus-service-connection`
   - Registry URL: `http://YOUR-NEXUS-IP:8082`
   - Username: `admin`
   - Password: Your Nexus password
4. Click **Save**

#### SonarQube Service Connection

1. Click **New service connection**
2. Select **SonarQube**
3. Configure:
   - Connection name: `sonarqube-service-connection`
   - Server URL: Leave empty for now (update after SonarQube is deployed)
   - Token: Leave empty for now
4. Click **Save**

### 4.4 Create Pipelines

1. Go to **Pipelines**
2. Click **New pipeline**
3. Select **GitHub** (or Azure Repos)
4. Select your repository
5. Select **Existing Azure Pipelines YAML file**
6. Create pipelines for:
   - `/pipelines/01-infrastructure.yml`
   - `/pipelines/02-tools.yml`
   - `/pipelines/03-application.yml`
   - `/pipelines/99-destroy.yml`

---

## Step 5: Push Code to Git

```bash
# Extract the downloaded ZIP
unzip final-project-devops.zip
cd final-project-devops

# Initialize git
git init
git add .
git commit -m "Initial commit"

# Add remote and push
git remote add origin https://github.com/USERNAME/REPO.git
git branch -M main
git push -u origin main
```

---

## Step 6: Run Infrastructure Pipeline

### 6.1 Run Pipeline

1. Go to **Pipelines**
2. Click **Infrastructure** pipeline
3. Click **Run pipeline**
4. Select action: `apply`
5. Click **Run**

### 6.2 Wait for Completion (~15-20 minutes)

Creates:
- VPC with subnets
- EKS cluster
- Network Load Balancer
- API Gateway
- Cognito User Pool

---

## Step 7: Run Tools Pipeline

### 7.1 Run Pipeline

1. Go to **Pipelines**
2. Click **Tools** pipeline
3. Click **Run pipeline**
4. Select action: `apply`
5. Click **Run**

### 7.2 Wait for Completion (~10-15 minutes)

Deploys:
- NGINX Ingress Controller
- ArgoCD
- SonarQube
- TargetGroupBinding

### 7.3 Get ArgoCD Password

```bash
aws eks update-kubeconfig --name devops-cluster --region us-east-1
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## Step 8: Run Application Pipeline

### 8.1 Run Pipeline

1. Go to **Pipelines**
2. Click **Application** pipeline
3. Click **Run pipeline**

### 8.2 What Happens

1. SonarQube code analysis
2. Docker image build
3. Trivy security scan
4. Push image to Nexus
5. Update deployment.yaml
6. Push to Git
7. ArgoCD auto-deploys

---

## Step 9: Access Services

### 9.1 Get API Gateway URL

```bash
# From AWS Console
# API Gateway → devops-api → Invoke URL
# Example: https://xxxxxx.execute-api.us-east-1.amazonaws.com/
```

### 9.2 Get Cognito Token

```bash
# Get Client ID
aws cognito-idp list-user-pool-clients --user-pool-id <POOL_ID> --region us-east-1

# Get Token
aws cognito-idp initiate-auth \
  --client-id <CLIENT_ID> \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=admin@devops.com,PASSWORD='Admin@123!' \
  --region us-east-1
```

### 9.3 Access Services

| Service | URL |
|---------|-----|
| Application | `https://API-GATEWAY/` |
| ArgoCD | `https://API-GATEWAY/argocd` |
| SonarQube | `https://API-GATEWAY/sonarqube` |

### 9.4 Using Browser

1. Install **ModHeader** browser extension
2. Add header: `Authorization: YOUR_ID_TOKEN`
3. Navigate to the URL

### 9.5 Credentials

| Service | Username | Password |
|---------|----------|----------|
| Cognito | admin@devops.com | Admin@123! |
| ArgoCD | admin | (from Step 7.3) |
| SonarQube | admin | admin |

---

## What is Cognito?

Cognito is AWS authentication service:

- **Purpose**: Secure access to all services
- **Flow**: Login → Get JWT Token → Use token in API requests
- **Protects**: Application, ArgoCD, SonarQube

```
User → Login to Cognito → Get JWT Token
          ↓
API Gateway → Validates Token → Grants Access
```

---

## Step 10: Destroy Everything

### 10.1 Run Destroy Pipeline

1. Go to **Pipelines**
2. Click **Destroy** pipeline
3. Click **Run pipeline**

### 10.2 Destroy Order

1. **Stage 1**: Destroy Tools (ArgoCD, SonarQube, NGINX)
2. **Stage 2**: Destroy Infrastructure (EKS, VPC, API Gateway)

### 10.3 Verify

```bash
# Check cluster is gone
aws eks describe-cluster --name devops-cluster --region us-east-1
# Should return: No cluster found
```

---

## Troubleshooting

### Terraform Init Fails

- Verify S3 bucket name in all 3 files
- Check AWS credentials in service connection

### kubectl Connection Refused

```bash
aws eks update-kubeconfig --name devops-cluster --region us-east-1
```

### Image Pull Error

```bash
kubectl get secret nexus-registry-secret -n default
```

### Destroy Fails

```bash
./scripts/cleanup.sh
```

---

## Quick Reference

### Files to Edit

| File | What to Change |
|------|----------------|
| `terraform/infrastructure/versions.tf` | `bucket = "YOUR-S3-BUCKET"` |
| `terraform/tools/versions.tf` | `bucket = "YOUR-S3-BUCKET"` |
| `terraform/tools/remote-state.tf` | `bucket = "YOUR-S3-BUCKET"` |

### Pipeline Order

```
1. Infrastructure (apply) → 15-20 min
       ↓
2. Tools (apply) → 10-15 min
       ↓
3. Application → 5-10 min
       ↓
4. Destroy (when done)
```

### Estimated Cost

~$200/month while running
