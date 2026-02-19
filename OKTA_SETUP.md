# Okta SAML Configuration Quick Reference

This document provides a quick reference for configuring Okta SAML integration with AWS IAM Identity Center for SageMaker Studio access.

## Okta SAML Application Settings

### Basic Configuration

| Setting | Value |
|---------|-------|
| Application Type | SAML 2.0 |
| App Name | AWS SageMaker Studio |
| Single sign-on URL | `https://signin.aws.amazon.com/saml` |
| Audience URI (SP Entity ID) | `https://signin.aws.amazon.com/saml` |
| Name ID format | EmailAddress |
| Application username | Email |
| Default RelayState | (leave blank) |

### SAML Attribute Statements

#### Required Attributes

| Name | Name Format | Value |
|------|-------------|-------|
| `https://aws.amazon.com/SAML/Attributes/RoleSessionName` | Unspecified | `user.email` |

#### Group Attribute Statement (Required)

| Name | Name Format | Filter Type | Filter Value | Value |
|------|-------------|-------------|--------------|-------|
| `https://aws.amazon.com/SAML/Attributes/Role` | Unspecified | Matches regex | `.*` | (empty) |

## Okta Groups Setup

Create the following groups in Okta:

1. **SageMakerAdmins**
   - Description: Full administrative access to SageMaker Studio
   - Members: Users who need admin access
   - Permissions: Full SageMaker access + AWS console access

2. **SageMakerUsers**
   - Description: Standard user access to SageMaker Studio
   - Members: Users who need standard access
   - Permissions: SageMaker Studio access with limited AWS console access

## Application Assignment

Assign both groups to the AWS SageMaker Studio application:

```
Okta Admin Console → Applications → AWS SageMaker Studio → Assignments
→ Assign → Assign to Groups
→ Select: SageMakerAdmins, SageMakerUsers
→ Done
```

## Metadata URL Format

Your Okta metadata URL will look like:

```
https://{okta-domain}/app/{app-id}/sso/saml/metadata
```

Example:
```
https://dev-12345678.okta.com/app/exk1234567890abcdef/sso/saml/metadata
```

**Where to find it:**
1. Okta Admin Console
2. Applications → AWS SageMaker Studio
3. Sign On tab
4. "Metadata URL" link (right-click and copy)

## AWS IAM Identity Center Configuration

### Enable IAM Identity Center

```bash
# Via AWS Console
AWS Console → IAM Identity Center → Enable

# Get instance details
aws sso-admin list-instances
```

Expected output:
```json
{
    "Instances": [
        {
            "InstanceArn": "arn:aws:sso:::instance/ssoins-1234567890abcdef",
            "IdentityStoreId": "d-1234567890"
        }
    ]
}
```

### Configure External Identity Provider

```
IAM Identity Center Console → Settings → Identity source
→ Actions → Change identity source
→ External identity provider
→ Upload Okta metadata OR enter metadata URL
→ Review and Accept
```

### Service Provider Metadata

Download AWS metadata file to configure in Okta (if needed):
```
IAM Identity Center → Settings → Identity source → 
Actions → Download metadata file
```

## Permission Set Assignments

After Terraform creates permission sets, assign them to Okta groups:

```
IAM Identity Center Console → AWS accounts
→ Select your account
→ Assign users or groups
→ Select groups: SageMakerAdmins, SageMakerUsers
→ Select permission sets (created by Terraform)
→ Submit
```

## User Authentication Flow

```
User Login (Okta)
    ↓
Okta Authenticates User
    ↓
SAML Assertion to AWS
    ↓
AWS IAM Identity Center
    ↓
AWS SSO Portal / Console Access
    ↓
SageMaker Console
    ↓
SageMaker Studio
    ↓
User Profile Auto-Created (first time)
    ↓
Studio Interface
```

## Testing Checklist

- [ ] Okta SAML app created with correct settings
- [ ] Groups created and assigned to application
- [ ] Users added to appropriate groups
- [ ] Metadata URL copied correctly
- [ ] IAM Identity Center enabled in AWS
- [ ] External IdP configured with Okta metadata
- [ ] Terraform applied successfully with SSO variables
- [ ] Permission sets assigned to groups in IAM Identity Center
- [ ] User can access AWS SSO portal from Okta
- [ ] User can launch SageMaker Studio
- [ ] User profile created automatically on first access

## Common Configuration Mistakes

### ❌ Incorrect Attribute Names

**Wrong:**
```
aws:SAML:Attributes:Role
RoleSessionName
```

**Correct:**
```
https://aws.amazon.com/SAML/Attributes/Role
https://aws.amazon.com/SAML/Attributes/RoleSessionName
```

### ❌ Missing Group Attribute Statement

The Role attribute **must** be configured as a Group Attribute Statement, not a regular Attribute Statement.

### ❌ Wrong Name ID Format

Must be `EmailAddress`, not `Persistent` or `Transient`.

### ❌ Incorrect Audience URI

Must be exactly: `https://signin.aws.amazon.com/saml`

Not: `https://console.aws.amazon.com/saml`

### ❌ Groups Not Assigned to Application

Groups must be assigned to the Okta application for users to access.

### ❌ Identity Source Still Set to "Identity Center directory"

Must be changed to "External identity provider" after configuration.

## Terraform Variables Reference

### Required Variables for SSO

```hcl
# Enable SSO mode
enable_sso = true

# AWS SSO configuration
sso_instance_arn      = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
sso_identity_store_id = "d-1234567890"

# Okta configuration  
okta_idp_metadata_url = "https://dev-12345678.okta.com/app/exk.../sso/saml/metadata"

# Group names (must match Okta groups)
sso_admin_group_name = "SageMakerAdmins"
sso_user_group_name  = "SageMakerUsers"
```

### How to Get Each Value

| Variable | How to Get |
|----------|------------|
| `sso_instance_arn` | `aws sso-admin list-instances \| jq -r '.Instances[0].InstanceArn'` |
| `sso_identity_store_id` | `aws sso-admin list-instances \| jq -r '.Instances[0].IdentityStoreId'` |
| `okta_idp_metadata_url` | Okta Admin → Apps → AWS SageMaker Studio → Sign On → Metadata URL |
| `sso_admin_group_name` | Name of Okta group for admins (you choose) |
| `sso_user_group_name` | Name of Okta group for users (you choose) |

## Verification Commands

### Verify IAM Identity Center

```bash
# List instances
aws sso-admin list-instances

# List permission sets
aws sso-admin list-permission-sets \
  --instance-arn "arn:aws:sso:::instance/ssoins-..."

# List account assignments
aws sso-admin list-account-assignments \
  --instance-arn "arn:aws:sso:::instance/ssoins-..." \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --permission-set-arn "arn:aws:sso:::permissionSet/..."
```

### Verify SageMaker Domain

```bash
# Check auth mode
aws sagemaker describe-domain \
  --domain-id $(terraform output -raw sagemaker_domain_id) \
  --query 'AuthMode'

# Expected output: "SSO"
```

### Verify User Profiles (After First Login)

```bash
# List user profiles
aws sagemaker list-user-profiles \
  --domain-id $(terraform output -raw sagemaker_domain_id)
```

## Troubleshooting Quick Reference

| Issue | Likely Cause | Solution |
|-------|--------------|----------|
| "Access Denied" in AWS Console | Permission set not assigned | Assign group to permission set in IAM Identity Center |
| SAML assertion error | Incorrect attribute mapping | Verify attribute names match exactly |
| User not in Okta app | Group not assigned | Assign user's group to Okta application |
| Can't launch Studio | Execution role missing permissions | Check IAM role has SageMakerFullAccess |
| User profile not created | Haven't accessed SageMaker Console | User must visit SageMaker Console first |
| Identity source error | External IdP not configured | Change identity source to external provider |

## Support Resources

- **Okta Documentation**: https://help.okta.com/en-us/Content/Topics/Apps/Apps_App_Integration_Wizard_SAML.htm
- **AWS IAM Identity Center**: https://docs.aws.amazon.com/singlesignon/
- **AWS SAML Federation**: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_saml.html
- **SageMaker Domain Authentication**: https://docs.aws.amazon.com/sagemaker/latest/dg/gs-studio-onboard.html

## Quick Setup Script

Save this as `get-sso-config.sh`:

```bash
#!/bin/bash
# Get AWS SSO configuration for Terraform

echo "Getting AWS SSO Configuration..."
echo ""

INSTANCE_ARN=$(aws sso-admin list-instances --query 'Instances[0].InstanceArn' --output text)
IDENTITY_STORE_ID=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text)

echo "Add these to your terraform.tfvars:"
echo ""
echo "sso_instance_arn      = \"$INSTANCE_ARN\""
echo "sso_identity_store_id = \"$IDENTITY_STORE_ID\""
echo ""
echo "Don't forget to add:"
echo "okta_idp_metadata_url = \"<your-okta-metadata-url>\""
```

Make it executable and run:
```bash
chmod +x get-sso-config.sh
./get-sso-config.sh
```
