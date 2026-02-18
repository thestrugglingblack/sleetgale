# sleetgale

Terraform configuration for creating a cost-optimized Amazon SageMaker Studio environment with optional custom domain, SSL, and Okta SSO authentication.

## Overview

This Terraform configuration creates a SageMaker Studio environment with:
- **Basic Mode (Default)**: SageMaker Studio domain with IAM-based authentication
- **Custom Domain Mode (Optional)**: Custom domain with SSL/TLS certificate AND web portal for Studio access
- **SSO Mode (Optional)**: AWS IAM Identity Center integration with Okta for SAML-based authentication
- VPC with 2 subnets across different availability zones
- Minimal instance types (ml.t3.medium for compute, "system" for JupyterServer)
- S3 bucket for SageMaker artifacts
- Security groups and IAM roles with least-privilege access

## Features

### Cost Optimization
- **Instance Types**: Uses `ml.t3.medium` (cheapest compute instance) and `system` (no-cost JupyterServer)
- **Authentication**: IAM mode by default (no additional SSO costs unless enabled)
- **Storage**: Standard S3 storage class
- **Networking**: Simple VPC setup with minimal resources

### Security & Enterprise Features
- **Custom Domain with Web Portal**: Access SageMaker Studio through your own domain with automated presigned URL generation
- **HTTPS Enforcement**: All traffic encrypted with valid SSL certificates
- **SSO Integration**: Optional Okta integration via AWS IAM Identity Center
- **Role-Based Access**: Configurable permission sets for admins and users
- **Private Networking**: VPC-based deployment with security groups

### Custom Domain Portal (NEW!)

When custom domain is enabled, a **serverless web portal** is automatically deployed that:
- Runs on AWS Lambda (pay per request, not 24/7)
- Provides a single-click "Launch Studio" button
- Generates fresh SageMaker presigned URLs automatically
- Redirects users seamlessly to their Studio environment
- **Costs ~$0.20-1/month instead of $7-10/month** (90% savings!)

No container management, no ECS costs - just simple serverless deployment.

See deployment instructions below for details.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with appropriate IAM permissions (see [IAM_PERMISSIONS.md](IAM_PERMISSIONS.md) for details)
  - Basic deployment: SageMaker, VPC, IAM, and S3 permissions
  - Custom domain: Route 53 and ACM permissions (including `route53:ListTagsForResource`)
  - SSO: AWS IAM Identity Center permissions
- **For Custom Domain**: 
  - Domain name registered (or Route 53 hosted zone)
  - DNS access to create validation records
- **For SSO/Okta Integration**:
  - AWS IAM Identity Center enabled in your AWS account
  - Okta administrator access to configure SAML application
  - SSO instance ARN and identity store ID

## Custom Domain with Portal

When you enable custom domain, a web portal is automatically deployed to provide seamless access to SageMaker Studio:

### Quick Setup

1. **Enable custom domain in terraform.tfvars**:
   ```hcl
   enable_custom_domain = true
   custom_domain_name   = "analysis.savantpraxis.com"
   route53_zone_id      = "Z1234567890ABC"
   ```

2. **Deploy infrastructure**:
   ```bash
   terraform init
   terraform apply
   ```

3. **Deploy Lambda portal** (optional - terraform handles this):
   ```bash
   ./deploy-portal.sh
   ```

4. **Access SageMaker Studio**:
   ```
   https://analysis.savantpraxis.com
   ```
   Click "Launch Studio" and you're in!

### What Gets Deployed

The custom domain setup includes:
- **AWS Lambda Function** - Serverless portal (128MB, pay per request)
- **Application Load Balancer** with SSL/TLS certificate
- **Route 53 DNS** records pointing to ALB
- **IAM roles** with SageMaker permissions
- **CloudWatch logs** for monitoring

### Architecture

```
User → analysis.savantpraxis.com
       ↓ (HTTPS)
     ALB + SSL Certificate
       ↓ (Invoke)
     Lambda Function (Serverless)
       ├── Show "Launch Studio" button
       ├── Generate presigned URL (AWS SDK)
       └── Redirect to SageMaker Studio
```

### Cost

- **Lambda**: ~$0.20-1/month (first 1M requests FREE)
- **ALB**: ~$16/month (required for custom domain)
- **Total**: ~$16-17/month

**vs ECS version**: Would be ~$23-26/month (Lambda saves $7-10/month)

## Basic Setup (No Custom Domain)

### Initialize Terraform

```bash
terraform init
```

### Preview Changes

```bash
terraform plan
```

### Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm the deployment.

### Access SageMaker Studio

After deployment, you can access SageMaker Studio:

1. Go to the AWS Console
2. Navigate to Amazon SageMaker > Domains
3. Select the "sleetgale" domain
4. Click on the user profile "default-user"
5. Click "Launch" > "Studio"

Alternatively, use the domain URL from the Terraform outputs:

```bash
terraform output sagemaker_domain_url
```

## Custom Domain with SSL Configuration

To enable custom domain with SSL certificate:

### 1. Update Configuration

Create a `terraform.tfvars` file:

```hcl
enable_custom_domain = true
custom_domain_name   = "sagemaker.savantpraxis.com"
route53_zone_id      = "Z1234567890ABC"  # Use existing savantpraxis.com zone
```

### 2. DNS Configuration Options

#### Option A: Use Existing Route 53 Zone (Recommended)

For savantpraxis.com domain:

```hcl
enable_custom_domain = true
custom_domain_name   = "sagemaker.savantpraxis.com"
route53_zone_id      = "Z1234567890ABC"  # Your existing savantpraxis.com zone ID
```

Find your zone ID with:

```bash
aws route53 list-hosted-zones --query 'HostedZones[?Name==`savantpraxis.com.`].Id' --output text
```

#### Option B: Use Existing ACM Certificate

If you already have a certificate for savantpraxis.com:

```hcl
enable_custom_domain = true
custom_domain_name   = "sagemaker.savantpraxis.com"
certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/..."
route53_zone_id      = "Z1234567890ABC"
```

### 3. Deploy with Custom Domain

```bash
terraform apply
```

The configuration will:
- Create an ACM certificate (if not provided)
- Validate the certificate via DNS
- Create an Application Load Balancer with HTTPS listener
- Configure HTTP to HTTPS redirect
- Create DNS records for the custom domain

### 4. Access via Custom Domain

Once deployed, access SageMaker Studio at:

```
https://sagemaker.savantpraxis.com
```

## Okta SSO Integration

Two methods are available for Okta integration:

### Method 1: ALB with Okta OIDC (Recommended - Simpler Setup)

Direct ALB integration with Okta using OpenID Connect. **Best for single account deployments.**

**Setup Time:** 15-20 minutes

1. **Create Okta OIDC Application**:
   - Okta Admin Console → Applications → Create App Integration
   - Select: **OIDC - OpenID Connect** → **Web Application**
   - Sign-in redirect URI: `https://your-domain.com/oauth2/idpresponse`

2. **Configure Terraform**:
   ```hcl
   enable_custom_domain = true
   custom_domain_name   = "analysis.savantpraxis.com"
   route53_zone_id      = "Z1234567890ABC"
   
   # Enable Okta OIDC authentication
   enable_okta_auth             = true
   okta_issuer_url              = "https://dev-12345678.okta.com/oauth2/default"
   okta_client_id               = "0oa..."
   okta_client_secret           = "your-secret"
   okta_authorization_endpoint  = "https://dev-12345678.okta.com/oauth2/default/v1/authorize"
   okta_token_endpoint          = "https://dev-12345678.okta.com/oauth2/default/v1/token"
   okta_user_info_endpoint      = "https://dev-12345678.okta.com/oauth2/default/v1/userinfo"
   ```

3. **Deploy**:
   ```bash
   terraform apply
   ```

**How it works:** ALB authenticates users with Okta before routing to Lambda. Lambda receives authenticated user identity and creates personalized presigned URLs.

📖 **Complete Guide**: [OKTA_LAMBDA_INTEGRATION.md](OKTA_LAMBDA_INTEGRATION.md)

### Method 2: IAM Identity Center + Okta SAML (Enterprise Setup)

AWS IAM Identity Center acts as SAML bridge between Okta and AWS. **Best for multi-account deployments.**

**Setup Time:** 30-45 minutes

To enable Okta-based authentication:

### Prerequisites

1. **Enable AWS IAM Identity Center**:
   - Go to AWS Console > IAM Identity Center
   - Click "Enable" if not already enabled
   - Note the SSO instance ARN and identity store ID

2. **Configure Okta SAML Application**:
   - Log in to Okta Admin Console
   - Create new SAML 2.0 application
   - Configure with AWS SSO settings
   - Note the IdP metadata URL

### 1. Update Terraform Configuration

Create or update `terraform.tfvars`:

```hcl
enable_sso              = true
sso_instance_arn        = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
sso_identity_store_id   = "d-1234567890"
okta_idp_metadata_url   = "https://dev-12345678.okta.com/app/exk.../sso/saml/metadata"
sso_admin_group_name    = "SageMakerAdmins"
sso_user_group_name     = "SageMakerUsers"
```

### 2. Configure Okta SAML Application

In Okta Admin Console:

1. **Create SAML Application**:
   - Applications > Create App Integration
   - Sign-in method: SAML 2.0
   - App name: "AWS SageMaker Studio"

2. **Configure SAML Settings**:
   - Single sign-on URL: `https://signin.aws.amazon.com/saml`
   - Audience URI: `https://signin.aws.amazon.com/saml`
   - Name ID format: EmailAddress
   - Application username: Email

3. **Configure Attribute Statements**:
   ```
   https://aws.amazon.com/SAML/Attributes/Role
   https://aws.amazon.com/SAML/Attributes/RoleSessionName
   ```

4. **Assign Users and Groups**:
   - Create groups: `SageMakerAdmins`, `SageMakerUsers`
   - Assign users to appropriate groups
   - Assign groups to the SAML application

5. **Get Metadata URL**:
   - Copy the "Metadata URL" from the Sign On tab
   - Use this as `okta_idp_metadata_url` in terraform.tfvars

### 3. Deploy with SSO

```bash
terraform apply
```

### 4. Complete AWS IAM Identity Center Setup

After Terraform deployment:

1. **Configure External IdP in IAM Identity Center**:
   - Go to IAM Identity Center console
   - Settings > Identity source
   - Choose "External identity provider"
   - Upload Okta metadata XML
   - Review and confirm changes

2. **Assign Permission Sets**:
   - In IAM Identity Center console
   - AWS accounts > Select your account
   - Assign users/groups to permission sets created by Terraform

### 5. Access SageMaker with SSO

1. Users log in via AWS SSO portal or Okta dashboard
2. Select the AWS account
3. Access SageMaker Studio Console
4. Launch Studio with their SSO credentials

## Combining Custom Domain and SSO

You can enable both features simultaneously:

```hcl
# Custom Domain
enable_custom_domain = true
custom_domain_name   = "sagemaker.savantpraxis.com"
route53_zone_id      = "Z1234567890ABC"  # Use existing savantpraxis.com zone

# Okta SSO
enable_sso              = true
sso_instance_arn        = "arn:aws:sso:::instance/ssoins-..."
sso_identity_store_id   = "d-..."
okta_idp_metadata_url   = "https://dev-....okta.com/app/.../sso/saml/metadata"
```

## Configuration Variables

### Basic Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region for resources | `us-east-1` | No |
| `environment` | Environment name | `dev` | No |
| `domain_name` | SageMaker domain name | `sleetgale` | No |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` | No |
| `subnet_cidrs` | Subnet CIDR blocks | `["10.0.1.0/24", "10.0.2.0/24"]` | No |

### Custom Domain Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `enable_custom_domain` | Enable custom domain with SSL | `false` | No |
| `custom_domain_name` | Custom domain name | `""` | Yes (if enabled) |
| `route53_zone_id` | Existing Route 53 zone ID | `""` | Conditional |
| `create_route53_zone` | Create new Route 53 zone | `false` | No |
| `certificate_arn` | Existing ACM certificate ARN | `""` | No |

### SSO Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `enable_sso` | Enable AWS SSO with Okta | `false` | No |
| `sso_instance_arn` | AWS SSO instance ARN | `""` | Yes (if enabled) |
| `sso_identity_store_id` | AWS SSO identity store ID | `""` | Yes (if enabled) |
| `okta_idp_metadata_url` | Okta SAML metadata URL | `""` | Yes (if enabled) |
| `sso_admin_group_name` | Admin group name | `SageMakerAdmins` | No |
| `sso_user_group_name` | User group name | `SageMakerUsers` | No |

## Outputs

The configuration provides the following outputs:

### Basic Outputs
- `sagemaker_domain_id`: The ID of the SageMaker Studio domain
- `sagemaker_domain_arn`: The ARN of the SageMaker Studio domain
- `sagemaker_domain_url`: The URL to access SageMaker Studio
- `sagemaker_user_profile_arn`: The ARN of the default user profile (IAM mode only)
- `sagemaker_execution_role_arn`: The ARN of the SageMaker execution role
- `sagemaker_bucket_name`: The S3 bucket name for SageMaker artifacts
- `vpc_id`: The VPC ID
- `subnet_ids`: The subnet IDs
- `auth_mode`: The authentication mode (IAM or SSO)

### Custom Domain Outputs
- `custom_domain_url`: The HTTPS URL for custom domain
- `alb_dns_name`: The ALB DNS name
- `certificate_arn`: The ACM certificate ARN
- `route53_zone_nameservers`: Name servers (if zone created)

### SSO Outputs
- `sso_permission_set_arns`: ARNs of admin and user permission sets

## Architecture

### Basic Mode (IAM Authentication)
```
Internet
    ↓
SageMaker Studio (IAM Auth)
    ↓
VPC (2 Subnets in Different AZs)
    ↓
S3 Bucket (Artifacts)
```

### Custom Domain Mode
```
Internet → Route 53
              ↓
         ACM Certificate
              ↓
Application Load Balancer (HTTPS)
              ↓
      SageMaker Studio
              ↓
    VPC + S3 Bucket
```

### SSO Mode with Okta
```
User → Okta (SAML) → AWS IAM Identity Center
                            ↓
                   AWS SSO Portal
                            ↓
                  SageMaker Studio (SSO Auth)
                            ↓
                  VPC + S3 Bucket
```

## Troubleshooting

### Custom Domain Issues

**Certificate Validation Pending**:
- Check DNS propagation: `dig CNAME _validation.sagemaker.savantpraxis.com`
- Verify Route 53 records were created
- Wait up to 30 minutes for DNS propagation

**ALB Health Checks Failing**:
- Verify security groups allow traffic from ALB to SageMaker
- Check target group health status in AWS Console
- Review ALB logs in CloudWatch

**Domain Not Resolving**:
- Verify Route 53 record points to ALB
- Check ALB is in "active" state
- Verify domain registrar nameservers match Route 53 zone

### SSO Issues

**Cannot Enable SSO**:
- Ensure IAM Identity Center is enabled in your AWS account
- Check you're using the correct SSO instance ARN
- Verify account permissions

**Okta Login Fails**:
- Verify SAML configuration matches AWS requirements
- Check Okta metadata URL is accessible
- Ensure users are assigned to the Okta application
- Review CloudTrail logs for authentication errors

**Permission Denied in SageMaker**:
- Verify permission sets are assigned to users/groups
- Check IAM policies attached to permission sets
- Ensure users have the correct group membership in Okta

**SSO Users Can't Access Domain**:
- In SSO mode, user profiles are created automatically on first login
- Verify the execution role has necessary permissions
- Check SageMaker domain status in AWS Console

### General Issues

**Terraform Apply Fails**:
- Run `terraform validate` to check syntax
- Ensure AWS credentials are configured
- Check AWS service quotas and limits
- Review IAM permissions for Terraform (see [IAM_PERMISSIONS.md](IAM_PERMISSIONS.md))

**IAM Permission Errors**:

Common Terraform permission errors and solutions:

- **`route53:ListTagsForResource` error**: Add Route 53 read permissions to your IAM user/group
  ```bash
  # Quick fix - apply Route 53 permissions
  aws iam put-user-policy \
    --user-name YOUR_USERNAME \
    --policy-name Route53Access \
    --policy-document file://route53-policy.json
  ```
- **ACM certificate errors**: Add ACM permissions
- **VPC/Subnet errors**: Add EC2 VPC permissions
- **See [IAM_PERMISSIONS.md](IAM_PERMISSIONS.md)** for complete permission requirements and policy examples
- Verify your current identity: `aws sts get-caller-identity`
- Check attached policies: `aws iam list-user-policies --user-name YOUR_USERNAME`

**ACM Certificate Validation Errors**:

If you get `UnsupportedCertificate` errors:
- **Error**: "The certificate must have a fully-qualified domain name"
- **Cause**: Certificate is not yet validated (status is PENDING_VALIDATION)
- **Solution**: Wait 15-30 minutes for DNS validation, then retry `terraform apply`
- Check status: `aws acm describe-certificate --certificate-arn YOUR_ARN --query Certificate.Status`
- **See [ACM_CERTIFICATE_ERROR_EXPLANATION.md](ACM_CERTIFICATE_ERROR_EXPLANATION.md)** for detailed troubleshooting

**High Costs**:
- Stop unused SageMaker apps in the console
- Use `terraform destroy` when infrastructure is not needed
- Monitor AWS Cost Explorer for detailed breakdown
- Consider using AWS Budgets for cost alerts

## Cost Considerations

### Basic Mode Costs
- **JupyterServer App**: "system" instance (no additional compute cost)
- **KernelGateway App**: ml.t3.medium (~$0.05/hour when running)
- **Storage**: S3 standard storage costs apply
- **Data Transfer**: Standard AWS data transfer costs

### Custom Domain Additional Costs
- **Application Load Balancer**: ~$0.0225/hour + data processing charges
- **Route 53 Hosted Zone**: $0.50/month (if created)
- **ACM Certificate**: Free
- **Data Transfer**: Standard ALB data transfer costs

### SSO Additional Costs
- **IAM Identity Center**: Free for workforce identities
- **Okta**: Requires Okta subscription (separate from AWS)
- **SSO Operations**: No additional AWS charges

**Important**: Always monitor costs and:
- Stop apps when not in use
- Delete the infrastructure when no longer needed (`terraform destroy`)
- Set up AWS Budgets for cost alerts
- Review AWS Cost Explorer regularly

## Security Best Practices

1. **Network Security**:
   - VPC with private subnets for production
   - Security groups with least-privilege rules
   - VPC endpoints for AWS services (optional)

2. **Authentication & Authorization**:
   - Use SSO for production environments
   - Implement MFA in Okta
   - Regular review of user access and permissions

3. **Data Protection**:
   - S3 bucket encryption enabled by default
   - Block public access on S3 buckets
   - SSL/TLS for all data in transit

4. **Monitoring & Auditing**:
   - Enable CloudTrail for API logging
   - Monitor CloudWatch logs
   - Set up alerts for suspicious activities
   - Regular security audits

## File Structure

```
.
├── main.tf              # Provider and Terraform configuration
├── variables.tf         # Input variables
├── network.tf           # VPC, subnets, security groups
├── iam.tf               # IAM roles and policies (IAM mode)
├── sso.tf               # SSO resources and IAM roles (SSO mode)
├── ssl.tf               # Custom domain, ACM, Route 53, ALB
├── sagemaker.tf         # SageMaker Studio domain and user profile
├── outputs.tf           # Output values
├── terraform.tfvars.example  # Example configuration
└── README.md            # This file
```

## Destroy Infrastructure

When you're done, destroy all resources to avoid ongoing costs:

```bash
terraform destroy
```

Type `yes` when prompted to confirm the destruction.

**Note**: If using SSO mode, you may need to manually remove permission set assignments in IAM Identity Center before destroying.

## License

This project is open source and available under the MIT License.