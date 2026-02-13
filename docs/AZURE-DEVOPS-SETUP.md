# Azure DevOps Configuration Guide

## Required Variable Group: `devops-config`

Create a variable group named `devops-config` in Azure DevOps Library with the following variables:

### Required Variables

| Variable Name | Description | Example Value |
|--------------|-------------|---------------|
| `aws-access-key-id` | AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
| `aws-secret-access-key` | AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` (Mark as Secret!) |
| `vault-address` | Vault server URL | `http://18.215.161.128:8200` |
| `vault-token` | Vault authentication token | `hvs.CAESI...` (Mark as Secret!) |
| `nexus-url` | Nexus repository URL | `http://18.215.161.128:8081` |

### Setting Up in Azure DevOps

1. Go to your Azure DevOps project
2. Navigate to **Pipelines** → **Library**
3. Click **+ Variable group**
4. Name it `devops-config`
5. Add the variables above
6. For sensitive values (keys, tokens), click the 🔒 icon to mark as secret
7. Save

## Required Service Connection: `aws-terraform-connection`

### Steps to Create

1. Go to **Project Settings** → **Service connections**
2. Click **New service connection** → **AWS for Terraform**
3. Configure:
   - **Connection name**: `aws-terraform-connection`
   - **Authentication method**: Choose one:
     - **Access Key**: Enter your AWS Access Key ID and Secret Access Key
     - **Assume Role** (optional): If using role assumption
4. Click **Verify and Save**

## Why Both Are Needed?

| Component | Used By | Purpose |
|-----------|---------|---------|
| `aws-terraform-connection` | Terraform tasks | Auth for Terraform operations |
| Variable Group variables | Script tasks | Auth for kubectl, AWS CLI |

## Common Errors

### Error: "The security token included in the request is invalid"

**Cause**: Script task cannot access AWS credentials

**Solution**:
1. Verify `aws-access-key-id` and `aws-secret-access-key` exist in `devops-config` variable group
2. Ensure the variables are not misspelled
3. Check that the variable group is referenced in the pipeline

### Error: "UnrecognizedClientException"

**Cause**: AWS credentials are invalid or expired

**Solution**:
1. Verify the AWS credentials are active in IAM
2. Check the credentials have proper permissions
3. Regenerate access keys if necessary

### Error: "connection refused - did you specify the right host or port"

**Cause**: kubectl not configured with cluster info

**Solution**:
1. Ensure infrastructure pipeline ran successfully first
2. Verify EKS cluster exists: `aws eks list-clusters --region us-east-1`
3. Check that `aws eks update-kubeconfig` step has AWS credentials

## Required IAM Permissions

The AWS credentials need these minimum permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "ec2:*",
        "elasticloadbalancing:*",
        "iam:*",
        "s3:*",
        "kms:*",
        "cognito-idp:*",
        "apigateway:*",
        "secretsmanager:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Quick Verification

Run this in Azure DevOps to verify your setup:

```yaml
- script: |
    echo "Testing AWS credentials..."
    aws sts get-caller-identity
    echo ""
    echo "Testing EKS access..."
    aws eks describe-cluster --name devops-cluster --region us-east-1 --query 'cluster.status'
  displayName: "Test AWS Configuration"
  env:
    AWS_ACCESS_KEY_ID: $(aws-access-key-id)
    AWS_SECRET_ACCESS_KEY: $(aws-secret-access-key)
    AWS_DEFAULT_REGION: "us-east-1"
```

## Pipeline Execution Order

1. **Infrastructure Pipeline** (`01-infrastructure.yml`)
   - Creates VPC, EKS, NLB, API Gateway, Cognito
   - Must complete successfully first

2. **Tools Pipeline** (`02-tools.yml`)
   - Deploys AWS LB Controller, NGINX, ArgoCD, SonarQube
   - Requires infrastructure to exist

3. **Application Pipeline** (`03-application.yml`)
   - Builds and deploys the sample app
   - Requires tools to be ready
