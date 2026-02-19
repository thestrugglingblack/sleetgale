```text
 ______     __         ______     ______     ______   ______     ______     __         ______    
/\  ___\   /\ \       /\  ___\   /\  ___\   /\__  _\ /\  ___\   /\  __ \   /\ \       /\  ___\   
\ \___  \  \ \ \____  \ \  __\   \ \  __\   \/_/\ \/ \ \ \__ \  \ \  __ \  \ \ \____  \ \  __\   
 \/\_____\  \ \_____\  \ \_____\  \ \_____\    \ \_\  \ \_____\  \ \_\ \_\  \ \_____\  \ \_____\ 
  \/_____/   \/_____/   \/_____/   \/_____/     \/_/   \/_____/   \/_/\/_/   \/_____/   \/_____/                                                                                                  
```

## Table of Contents
- [Overview](#overview)
- [Cost Optimization Features](#cost-optimization-features)
- [Configuration Details](#configuration-details)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)
Terraform configuration for creating the cheapest Amazon SageMaker Studio instance.

## Overview

This project deploys a complete SageMaker Studio environment with:
- **Serverless Lambda Portal**: Web interface for one-click access to SageMaker Studio
- **Auth0 Authentication**: OIDC-based authentication via Application Load Balancer
- **Custom Domain**: Access Studio through your branded domain (e.g., `analysis.yourcompany.com`)
- **Cost-Optimized**: Lambda-based portal (~$0.20-1/month vs $7-10/month for container-based solutions)
- **Secure**: All traffic over HTTPS with SSL/TLS certificates

## Architecture: Auth0 → Lambda Portal → SageMaker Studio

```
User visits: https://analysis.yourcompany.com
    ↓
ALB checks authentication
    ↓ (not authenticated)
Redirect to Auth0 Login
    ↓
User authenticates with Auth0
    ↓
Auth0 redirects back to ALB
    ↓
ALB validates token → invokes Lambda
    ↓
Lambda Portal
    ├── Extracts user identity (email)
    ├── Maps to SageMaker user profile
    ├── Generates presigned URL
    └── Displays "Launch Studio" button
    ↓
User clicks "Launch Studio"
    ↓
Redirects to SageMaker Studio
    ↓
User accesses their personal workspace
```

## Features

### Lambda Portal
- **Serverless**: AWS Lambda (128MB, pay per request)
- **Auto-scaling**: Handles any number of concurrent users
- **Low cost**: First 1M requests/month FREE, then $0.20 per 1M
- **No containers**: No Docker, no ECS, no image management
- **Fast deployment**: Updates in seconds

### Auth0 Integration
- **ALB Auth0**: Authentication handled at load balancer level
- **Automatic user mapping**: Email → SageMaker profile conversion
- **Session management**: Configurable session timeout
- **Zero application code**: All auth logic in AWS infrastructure

### SageMaker Studio
- **Cost-optimized instances**: ml.t3.medium for compute
- **Secure VPC**: Private networking with security groups
- **IAM roles**: Least-privilege access controls
- **S3 storage**: Artifacts and notebooks

## Prerequisites

- **Terraform** >= 1.0
- **AWS CLI** configured with credentials
- **AWS Account** with appropriate permissions (see [IAM_PERMISSIONS.md](IAM_PERMISSIONS.md))
- **Domain name**: Registered domain or Route 53 hosted zone
- **Auth0 account**: Admin access to configure Auth0 application

## Quick Start

### 1. Create Auth0 Application

1. Log in to Auth0 Dashboard (https://manage.auth0.com/)
2. **Applications** → **Create Application**
3. Select **Regular Web Application** → **Create**
4. Go to **Settings** tab and configure:
   - **Name**: SageMaker Studio Portal
   - **Allowed Callback URLs**: `https://YOUR-DOMAIN/oauth2/idpresponse`
   - **Allowed Logout URLs**: `https://YOUR-DOMAIN`
5. Save and note:
   - **Client ID**
   - **Client Secret**
   - **Domain** (e.g., `dev-12345678.us.auth0.com`)

### 2. Configure Terraform

Create `terraform.tfvars`:

```hcl
# Basic Configuration
aws_region   = "us-east-1"
environment  = "production"
domain_name  = "sleetgale"

# Custom Domain Configuration
enable_custom_domain = true
custom_domain_name   = "analysis.yourcompany.com"
route53_zone_id      = "Z1234567890ABC"  # Your existing hosted zone

# Auth0 Configuration
enable_auth0        = true
auth0_domain        = "dev-12345678.us.auth0.com"
auth0_client_id     = "AbCdEfGhIjKlMnOpQrSt1234567890"
auth0_client_secret = "your-client-secret"
```

**Finding your Route 53 Zone ID:**
```bash
aws route53 list-hosted-zones --query 'HostedZones[?Name==`yourcompany.com.`].Id' --output text
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy
terraform apply
```

This creates:
- VPC with subnets and security groups
- SageMaker Studio domain and default user profile
- Application Load Balancer with SSL certificate
- Lambda function for portal
- Route 53 DNS records
- IAM roles and policies

### 4. Deploy Lambda Portal

The Lambda function code is deployed automatically by Terraform, but you can update it manually if needed:

```bash
./deploy-portal.sh
```

### 5. Access SageMaker Studio

1. Open your browser (use incognito/private mode for testing)
2. Navigate to: `https://analysis.yourcompany.com`
3. You'll be redirected to Auth0 for authentication
4. Log in with your Auth0 credentials
5. See the portal with "Launch Studio" button
6. Click to access your SageMaker Studio workspace

## User Profile Mapping

The Lambda portal automatically maps Auth0 users to SageMaker user profiles:

- **Auth0 user**: `jane.doe@company.com`
- **SageMaker profile**: `jane-doe-company-com`

The portal:
1. Extracts the email from ALB Auth0 headers
2. Converts email to valid profile name (alphanumeric + hyphens)
3. Checks if the profile exists in SageMaker
4. Generates a presigned URL for that specific user's workspace
5. Each user gets their own isolated Studio environment

## Cost Breakdown

| Component | Monthly Cost |
|-----------|--------------|
| SageMaker Studio (minimal usage) | Variable |
| Lambda Portal | $0.20-1 |
| Application Load Balancer | ~$16 |
| Route 53 Hosted Zone | $0.50 |
| ACM Certificate | Free |
| **Total Infrastructure** | **~$16.70-17.50** |

**Okta**: No additional AWS cost (uses your existing Okta subscription)

## Configuration Options

### Using Existing DNS and SSL Resources (IMPORTANT)

If you already have a Route53 hosted zone and/or ACM certificate, use this configuration to **prevent Terraform from recreating or modifying** your existing resources:

```hcl
# terraform.tfvars
enable_custom_domain = true
custom_domain_name   = "analysis.yourcompany.com"

# Use EXISTING Route53 zone (prevents zone creation)
create_route53_zone = false  # This is the default, but be explicit
route53_zone_id     = "Z1234567890ABC"  # Your existing zone ID

# Use EXISTING ACM certificate (prevents cert creation)
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

**How to find your existing resources:**

```bash
# Find Route53 Zone ID
aws route53 list-hosted-zones --query 'HostedZones[?Name==`yourcompany.com.`].[Id,Name]' --output table

# Find ACM Certificate ARN (must be in us-east-1 for ALB)
aws acm list-certificates --region us-east-1 --query 'CertificateSummaryList[?DomainName==`*.yourcompany.com`].[CertificateArn,DomainName]' --output table
```

**What Terraform will create:**
- ✅ Only ONE Route53 A record pointing to the ALB (for your custom_domain_name)
- ✅ NO new Route53 zone
- ✅ NO new ACM certificate
- ✅ NO certificate validation records

**What happens if you DON'T specify these:**
- ❌ Terraform will create a NEW ACM certificate (and validation records)
- ❌ Certificate validation will add DNS records to your zone
- ⚠️ This could conflict with existing certificates

### Basic SageMaker (No Custom Domain)

If you just want SageMaker Studio without custom domain or Okta:

```hcl
# terraform.tfvars
aws_region  = "us-east-1"
environment = "dev"
domain_name = "sleetgale"

# Keep these false or omit them
enable_custom_domain = false
enable_auth0     = false
```

Access via AWS Console:
1. AWS Console → SageMaker → Domains
2. Select domain → Select user profile
3. Launch → Studio

### Custom Domain Without Okta

Portal accessible to anyone (uses AWS IAM for SageMaker access):

```hcl
enable_custom_domain = true
custom_domain_name   = "analysis.yourcompany.com"
route53_zone_id      = "Z1234567890ABC"

enable_auth0     = false
```

### Custom Domain With Okta (Recommended)

Secure portal with Auth0 authentication:

```hcl
enable_custom_domain = true
custom_domain_name   = "analysis.yourcompany.com"
route53_zone_id      = "Z1234567890ABC"

enable_auth0     = true
# ... (Auth0 settings as shown above)
```

## Documentation

- **[SETUP.md](SETUP.md)** - Detailed setup and configuration guide
- **[AUTH0_LAMBDA_INTEGRATION.md](AUTH0_LAMBDA_INTEGRATION.md)** - Complete Auth0 integration guide
- **[IAM_PERMISSIONS.md](IAM_PERMISSIONS.md)** - Required AWS IAM permissions
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Common commands and troubleshooting

## Troubleshooting

### Portal shows 503 error
- Check Lambda logs: `aws logs tail /aws/lambda/sagemaker-portal --follow`
- Verify Lambda has permissions to call SageMaker APIs
- Check ALB target health: `aws elbv2 describe-target-health --target-group-arn <ARN>`

### Auth0 authentication fails
- Verify Auth0 callback URL matches your domain exactly
- Check client ID and secret in terraform.tfvars
- Ensure auth0_domain is correct for your tenant
- Review ALB logs for authentication errors

### User profile not found
- Ensure SageMaker user profile exists with correct naming
- Profile name format: lowercase email with @ and . replaced by hyphens
- Example: `user@company.com` → `user-company-com`
- Create profile manually if needed or update Lambda to auto-create

### Certificate validation stuck
- Ensure DNS records are created in Route 53
- Check that your domain's nameservers point to Route 53
- Certificate validation can take 5-30 minutes
- View certificate status: `aws acm describe-certificate --certificate-arn <ARN>`

## Security Best Practices

1. **Rotate Okta client secret** regularly
2. **Use AWS Secrets Manager** for sensitive values instead of terraform.tfvars
3. **Enable CloudTrail** for audit logging
4. **Configure session timeout** based on your security requirements
5. **Review IAM policies** to ensure least-privilege access
6. **Enable MFA** in Okta for all users
7. **Monitor CloudWatch logs** for suspicious activity

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will delete:
- SageMaker Studio domain and all user data
- Lambda function and logs
- Application Load Balancer
- Route 53 records (but not the hosted zone)
- VPC and networking resources

S3 buckets with data may need manual deletion due to protection policies.

## License

[Your license information here]

## Support

For issues or questions:
1. Check documentation in this repository
2. Review CloudWatch logs for errors
3. Verify configuration in terraform.tfvars
4. Check IAM permissions are correctly configured

## Contributing

[Your contribution guidelines here]
