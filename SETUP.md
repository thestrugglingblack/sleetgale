# Sleetgale Setup Guide

This guide provides detailed step-by-step instructions for setting up SageMaker Studio with custom domain, SSL, and Okta authentication.

## Table of Contents

1. [Basic Setup (IAM Mode)](#basic-setup-iam-mode)
2. [Custom Domain with SSL Setup](#custom-domain-with-ssl-setup)
3. [Okta SSO Integration Setup](#okta-sso-integration-setup)
4. [Combined Setup (Custom Domain + SSO)](#combined-setup-custom-domain--sso)
5. [Post-Deployment Verification](#post-deployment-verification)
6. [Common Issues and Solutions](#common-issues-and-solutions)

---

## Basic Setup (IAM Mode)

This is the simplest and most cost-effective setup. Perfect for development and testing.

### Prerequisites

- AWS CLI installed and configured
- Terraform >= 1.0 installed
- AWS account with appropriate permissions

### Steps

1. **Clone the Repository**
   ```bash
   git clone https://github.com/thestrugglingblack/sleetgale.git
   cd sleetgale
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Review the Plan**
   ```bash
   terraform plan
   ```

4. **Deploy**
   ```bash
   terraform apply
   ```
   Type `yes` when prompted.

5. **Access SageMaker Studio**
   ```bash
   # Get the domain URL
   terraform output sagemaker_domain_url
   
   # Or access via AWS Console:
   # Console → SageMaker → Domains → sleetgale → default-user → Launch Studio
   ```

### Cost: ~$0.05/hour when running (ml.t3.medium)

---

## Custom Domain with SSL Setup

Enable HTTPS access to SageMaker via your own domain name.

### Prerequisites

- Domain name (e.g., `savantpraxis.com`)
- DNS access (Route 53 or external DNS provider)
- Basic setup completed OR fresh installation

### Option A: Using Route 53 (Recommended)

#### Step 1: Prepare Domain in Route 53

**If domain is already in Route 53:**
```bash
# Get your hosted zone ID for savantpraxis.com
aws route53 list-hosted-zones --query 'HostedZones[?Name==`savantpraxis.com.`].Id' --output text
```

**If domain needs to be added to Route 53:**
- Go to Route 53 Console
- Create hosted zone for your domain
- Note the name servers
- Update your domain registrar with Route 53 name servers

#### Step 2: Create terraform.tfvars

Create a `terraform.tfvars` file:

```hcl
# Using existing Route 53 zone for savantpraxis.com
enable_custom_domain = true
custom_domain_name   = "sagemaker.savantpraxis.com"
route53_zone_id      = "Z1234567890ABC"  # Your zone ID from step 1

# Note: create_route53_zone is not needed since we're using an existing zone
```

#### Step 3: Deploy

```bash
terraform apply
```

This will:
- Create ACM certificate
- Create DNS validation records
- Wait for certificate validation (~5-30 minutes)
- Create Application Load Balancer
- Configure HTTPS listener with SSL
- Create DNS A record for your domain

#### Step 4: Verify

```bash
# Check certificate status
terraform output certificate_arn

# Get custom domain URL
terraform output custom_domain_url

# If zone was created, get name servers to configure at registrar
terraform output route53_zone_nameservers
```

#### Step 5: Access

```bash
# Wait a few minutes for DNS propagation, then access:
https://sagemaker.savantpraxis.com
```

### Option B: Using Existing Certificate

If you already have an ACM certificate:

```hcl
# terraform.tfvars
enable_custom_domain = true
custom_domain_name   = "sagemaker.savantpraxis.com"
route53_zone_id      = "Z1234567890ABC"
certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/..."
```

### Option C: Using External DNS Provider (Not Recommended for savantpraxis.com)

**Note**: For savantpraxis.com, it's recommended to use the existing Route53 zone (Option A) instead of this approach.

If you need to use an external DNS provider:

1. Deploy with Route 53 zone creation:
   ```hcl
   enable_custom_domain = true
   custom_domain_name   = "sagemaker.yourdomain.com"
   create_route53_zone  = true
   ```

2. After deployment, get name servers:
   ```bash
   terraform output route53_zone_nameservers
   ```

3. Create NS records at your DNS provider pointing to these name servers

### Additional Cost: ~$16-20/month (ALB)

---

## Okta SSO Integration Setup

Enable enterprise single sign-on with Okta SAML 2.0.

### Prerequisites

- Okta account with admin access
- AWS account
- Basic setup completed OR fresh installation

### Part 1: Enable AWS IAM Identity Center

#### Step 1: Enable IAM Identity Center

1. **AWS Console → IAM Identity Center**
2. Click **"Enable"**
3. Select region (must match your Terraform region)
4. Wait for activation (~2-3 minutes)

#### Step 2: Get SSO Configuration Details

```bash
# Get SSO instance ARN
aws sso-admin list-instances --query 'Instances[0].InstanceArn' --output text

# Get identity store ID
aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text
```

Save these values - you'll need them for Terraform.

### Part 2: Configure Okta SAML Application

#### Step 1: Create SAML Application in Okta

1. **Okta Admin Console → Applications → Create App Integration**
2. Select **"SAML 2.0"**
3. Click **"Next"**

#### Step 2: Configure General Settings

- **App name**: `AWS SageMaker Studio`
- **App logo**: (optional)
- Click **"Next"**

#### Step 3: Configure SAML Settings

**Single sign-on URL:**
```
https://signin.aws.amazon.com/saml
```

**Audience URI (SP Entity ID):**
```
https://signin.aws.amazon.com/saml
```

**Name ID format:**
```
EmailAddress
```

**Application username:**
```
Email
```

**Attribute Statements:**

| Name | Name format | Value |
|------|-------------|-------|
| `https://aws.amazon.com/SAML/Attributes/RoleSessionName` | Unspecified | `user.email` |

**Group Attribute Statements:**

| Name | Name format | Filter | Value |
|------|-------------|--------|-------|
| `https://aws.amazon.com/SAML/Attributes/Role` | Unspecified | Matches regex: `.*` | (leave value empty) |

Click **"Next"**, then **"Finish"**

#### Step 4: Get Metadata URL

1. Go to **"Sign On"** tab
2. Under **"Metadata URL"**, right-click **"Metadata URL"** and copy link
3. Save this URL - you'll need it for Terraform

Example: `https://dev-12345678.okta.com/app/exk1234567890abcdef/sso/saml/metadata`

#### Step 5: Create Groups in Okta

1. **Okta Admin Console → Directory → Groups**
2. Create two groups:
   - `SageMakerAdmins` - Full administrative access
   - `SageMakerUsers` - Standard user access
3. Add users to appropriate groups

#### Step 6: Assign Application to Groups

1. **Applications → AWS SageMaker Studio → Assignments**
2. Click **"Assign"** → **"Assign to Groups"**
3. Assign both `SageMakerAdmins` and `SageMakerUsers`
4. Click **"Done"**

### Part 3: Deploy with Terraform

#### Step 1: Create terraform.tfvars

```hcl
# Enable SSO
enable_sso = true

# SSO configuration (from Part 1, Step 2)
sso_instance_arn      = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
sso_identity_store_id = "d-1234567890"

# Okta configuration (from Part 2, Step 4)
okta_idp_metadata_url = "https://dev-12345678.okta.com/app/exk.../sso/saml/metadata"

# Group names (must match Okta groups from Part 2, Step 5)
sso_admin_group_name = "SageMakerAdmins"
sso_user_group_name  = "SageMakerUsers"
```

#### Step 2: Deploy

```bash
terraform apply
```

This will:
- Create SSO permission sets for admins and users
- Create IAM execution role for SSO
- Update SageMaker domain to SSO mode
- Configure necessary IAM policies

#### Step 3: Get Permission Set ARNs

```bash
terraform output sso_permission_set_arns
```

### Part 4: Complete IAM Identity Center Setup

#### Step 1: Configure External Identity Provider

1. **IAM Identity Center Console → Settings → Identity source**
2. Click **"Actions"** → **"Change identity source"**
3. Select **"External identity provider"**
4. Click **"Next"**

#### Step 2: Configure SAML

1. **Service provider metadata:**
   - Download the metadata file (you'll need this for Okta)
   
2. **Identity provider metadata:**
   - Option A: Upload Okta metadata XML
     - Download from Okta metadata URL
     - Upload the file
   - Option B: Enter metadata URL directly (if supported)

3. Review and **"Accept"** the changes

#### Step 3: Update Okta SAML Configuration

Go back to Okta and update the SAML settings with AWS-provided values:

1. **Okta Admin Console → Applications → AWS SageMaker Studio → General**
2. Update **"SAML Settings"** with:
   - ACS URL from AWS metadata
   - Entity ID from AWS metadata
   - Attribute mappings for role and session

#### Step 4: Configure Automatic Provisioning (Optional)

For automatic user provisioning:

1. **IAM Identity Center → Settings → Automatic provisioning**
2. Enable provisioning
3. Copy SCIM endpoint and access token
4. Configure in Okta under **Provisioning** tab

### Part 5: Assign Users to Permission Sets

#### Step 1: Assign Permission Sets

1. **IAM Identity Center Console → AWS accounts**
2. Select your AWS account
3. Click **"Assign users or groups"**
4. Search and select your Okta groups:
   - Assign `SageMakerAdmins` to admin permission set
   - Assign `SageMakerUsers` to user permission set

#### Step 2: Verify Assignment

Users should now see the AWS account in their AWS access portal.

### Part 6: Test Authentication

#### Step 1: Access AWS Portal

Users can access via:
- AWS SSO portal URL (from IAM Identity Center)
- Okta dashboard → AWS SageMaker Studio tile

#### Step 2: Login Flow

1. User clicks on AWS SageMaker Studio in Okta
2. Okta authenticates the user
3. SAML assertion sent to AWS
4. User lands in AWS Console
5. Navigate to SageMaker → Domains → sleetgale
6. User profile is automatically created on first access
7. Click **"Launch Studio"**

### Additional Cost: $0 (IAM Identity Center free for workforce)

**Note:** Okta subscription required (separate from AWS costs)

---

## Combined Setup (Custom Domain + SSO)

Enable both custom domain and Okta SSO for enterprise production deployment.

### Prerequisites

- All prerequisites from both Custom Domain and SSO sections
- Completed Part 1 of Okta SSO setup (IAM Identity Center enabled)
- Completed Part 2 of Okta SSO setup (Okta configured)

### Step 1: Create Comprehensive terraform.tfvars

```hcl
# Basic configuration
aws_region  = "us-east-1"
environment = "production"
domain_name = "sleetgale-prod"

# Custom Domain Configuration
enable_custom_domain = true
custom_domain_name   = "sagemaker.savantpraxis.com"
route53_zone_id      = "Z1234567890ABC"

# Or create new zone:
# create_route53_zone = true

# Okta SSO Configuration
enable_sso            = true
sso_instance_arn      = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
sso_identity_store_id = "d-1234567890"
okta_idp_metadata_url = "https://dev-12345678.okta.com/app/exk.../sso/saml/metadata"
sso_admin_group_name  = "SageMakerAdmins"
sso_user_group_name   = "SageMakerUsers"
```

### Step 2: Deploy

```bash
terraform apply
```

This combines both setups:
- Custom domain with SSL certificate
- Application Load Balancer with HTTPS
- SSO authentication mode
- Permission sets for role-based access

### Step 3: Complete SSO Setup

Follow Part 4 from the Okta SSO Integration section to:
- Configure external identity provider in IAM Identity Center
- Assign users to permission sets

### Step 4: Access

Users will:
1. Login via Okta
2. Access SageMaker via custom domain: `https://sagemaker.savantpraxis.com`
3. Authenticate with SSO credentials
4. Launch Studio with their assigned permissions

### Total Additional Cost: ~$16-20/month (ALB only, SSO is free)

---

## Post-Deployment Verification

### Verify Custom Domain

```bash
# Check DNS resolution
dig sagemaker.savantpraxis.com

# Check SSL certificate
curl -vI https://sagemaker.savantpraxis.com 2>&1 | grep -A 10 "SSL certificate"

# Verify HTTPS redirect
curl -I http://sagemaker.savantpraxis.com
```

### Verify SSO Configuration

```bash
# List permission sets
aws sso-admin list-permission-sets \
  --instance-arn "arn:aws:sso:::instance/ssoins-..."

# Verify SageMaker domain auth mode
aws sagemaker describe-domain \
  --domain-id $(terraform output -raw sagemaker_domain_id) \
  --query 'AuthMode'
```

### Verify Infrastructure

```bash
# Check all outputs
terraform output

# Verify specific resources
terraform show | grep -A 5 "aws_lb.sagemaker_alb"
terraform show | grep -A 5 "aws_sagemaker_domain.sleetgale"
```

### Test End-to-End Access

1. **IAM Mode:**
   - AWS Console → SageMaker → Domains → sleetgale → default-user → Launch Studio

2. **SSO Mode:**
   - Login to Okta
   - Click AWS SageMaker Studio app
   - Navigate to SageMaker Console
   - Launch Studio (user profile auto-created)

3. **Custom Domain:**
   - Navigate to `https://sagemaker.savantpraxis.com`
   - Should see valid SSL certificate
   - Should redirect from HTTP to HTTPS

---

## Common Issues and Solutions

### Custom Domain Issues

**Issue: Certificate validation stuck**
```bash
# Check DNS records
aws route53 list-resource-record-sets --hosted-zone-id Z123... \
  | grep -A 3 "_validation"

# Solution: Wait up to 30 minutes for DNS propagation
# If still stuck, verify Route 53 zone is correct
```

**Issue: Domain not resolving**
```bash
# Check A record exists
dig sagemaker.savantpraxis.com

# Solution: Verify ALB is active and DNS record is created
aws elbv2 describe-load-balancers \
  --names sleetgale-alb
```

**Issue: SSL certificate error**
```bash
# Verify certificate domain matches
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw certificate_arn)

# Solution: Ensure custom_domain_name matches certificate domain
```

### SSO Issues

**Issue: "Access denied" when launching Studio**
```bash
# Check execution role permissions
aws iam get-role --role-name sleetgale-sso-sagemaker-execution-role

# Solution: Verify role has SageMakerFullAccess policy attached
```

**Issue: Users can't see AWS account in portal**
```bash
# Check permission set assignments
aws sso-admin list-account-assignments \
  --instance-arn "arn:aws:sso:::instance/..." \
  --account-id $(aws sts get-caller-identity --query Account --output text)

# Solution: Assign users/groups to permission sets in IAM Identity Center
```

**Issue: SAML assertion errors**
```
# Common causes:
# 1. Incorrect attribute mappings in Okta
# 2. Missing group assignments
# 3. Identity source not set to external provider

# Solution: Verify Okta SAML configuration matches AWS requirements
# Check CloudTrail logs for detailed error messages
```

**Issue: User profile not created automatically**
```bash
# Verify domain is in SSO mode
aws sagemaker describe-domain \
  --domain-id $(terraform output -raw sagemaker_domain_id) \
  --query 'AuthMode'

# Solution: User must access SageMaker Console first
# Profile is created on first SageMaker Console access
```

### Terraform Issues

**Issue: "Error creating SageMaker Domain"**
```
Error: error creating SageMaker Domain: ValidationException: 
The domain cannot be created in SSO mode without proper configuration
```
```bash
# Solution: Ensure sso_instance_arn and sso_identity_store_id are correct
# Verify IAM Identity Center is enabled
aws sso-admin list-instances
```

**Issue: "Certificate validation timeout"**
```bash
# Increase timeout or complete validation manually
# Check that Route 53 zone is accessible and records are created

# Manual fix:
aws route53 list-resource-record-sets \
  --hosted-zone-id $(terraform output -raw route53_zone_id)
```

**Issue: "Duplicate resource" errors**
```bash
# If switching from IAM to SSO mode, state may need updating
terraform state list
terraform state rm aws_sagemaker_user_profile.default_user

# Then re-apply
terraform apply
```

### Migration Issues

**Issue: Switching from IAM to SSO mode**
```bash
# Warning: This recreates the SageMaker domain
# All data and apps will be lost

# Recommended: Create new domain with different name
# Then migrate data manually

# terraform.tfvars
domain_name = "sleetgale-sso"
enable_sso = true
```

### Getting Help

1. **Check Terraform Logs:**
   ```bash
   TF_LOG=DEBUG terraform apply
   ```

2. **Check AWS CloudTrail:**
   - Console → CloudTrail → Event history
   - Filter by error events

3. **Check SageMaker Logs:**
   - Console → SageMaker → Domains → Events

4. **AWS Support:**
   - Open support case if infrastructure issues persist
   - Provide error messages and CloudTrail logs

---

## Additional Resources

- [AWS SageMaker Documentation](https://docs.aws.amazon.com/sagemaker/)
- [AWS IAM Identity Center Documentation](https://docs.aws.amazon.com/singlesignon/)
- [Okta SAML Configuration Guide](https://help.okta.com/en-us/Content/Topics/Apps/Apps_App_Integration_Wizard_SAML.htm)
- [AWS Certificate Manager Documentation](https://docs.aws.amazon.com/acm/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

## Cost Summary

| Configuration | Monthly Cost (Estimate) | Notes |
|---------------|-------------------------|-------|
| Basic (IAM) | ~$0 + usage | Only pay when apps are running (~$0.05/hr) |
| + Custom Domain | +$16-20 | Application Load Balancer |
| + Route 53 Zone | +$0.50 | If creating new zone |
| + SSO | +$0 | IAM Identity Center free for workforce |
| + Okta | Varies | Requires Okta subscription (external) |

**Usage Costs:**
- ml.t3.medium: ~$0.05/hour (only when running)
- S3 storage: Standard rates apply
- Data transfer: Standard AWS rates apply

**Important:** Always stop SageMaker apps when not in use to minimize costs!

```bash
# Stop all apps via AWS Console or CLI
aws sagemaker list-apps --domain-id $(terraform output -raw sagemaker_domain_id)
```
