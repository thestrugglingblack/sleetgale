# Auth0 Integration with Lambda Portal

## Quick Answer: YES, It Works!

The Lambda portal solution is **fully compatible** with Auth0 authentication. The integration provides a seamless experience where users:

1. Authenticate once via Auth0
2. Access the custom domain (e.g., analysis.yourcompany.com)
3. Automatically launch SageMaker Studio with their identity

## Architecture

```
┌─────────┐
│  User   │
└────┬────┘
     │ 1. Access custom domain
     │    https://analysis.yourcompany.com
     ▼
┌─────────────────────────────┐
│  Application Load Balancer  │
│  - HTTPS Listener (443)     │
│  - Auth0 Authentication │
└─────────────┬───────────────┘
              │ 2. Authenticate via Auth0 (if not logged in)
              │    User redirected to Auth0 → Login → Return
              │
              │ 3. Authenticated request with user headers
              ▼
┌─────────────────────────────┐
│     Lambda Function         │
│  - Extract user from ALB    │
│  - Generate presigned URL   │
│  - Use correct user profile │
└─────────────┬───────────────┘
              │ 4. Create presigned URL for user's profile
              ▼
┌─────────────────────────────┐
│    SageMaker Studio         │
│  - User's workspace         │
│  - Auto-profile creation    │
└─────────────────────────────┘
```

## Two Integration Methods

### Method 1: ALB with Auth0 (Recommended)

**Best for:** Modern Auth0 deployments, simplest integration

ALB directly integrates with Auth0 using OIDC, no SAML needed.

**Benefits:**
- ✅ No SAML configuration required
- ✅ ALB handles all authentication logic
- ✅ Lambda receives authenticated user automatically
- ✅ Automatic session management
- ✅ Easy to configure

**Setup Time:** 15-20 minutes

### Method 2: IAM Identity Center + Okta SAML

**Best for:** Enterprise setups, AWS Organizations, multiple AWS accounts

Uses AWS IAM Identity Center as SAML bridge between Okta and AWS.

**Benefits:**
- ✅ Centralized user management
- ✅ Works across multiple AWS accounts
- ✅ Fine-grained IAM permissions
- ✅ AWS SSO portal access

**Setup Time:** 30-45 minutes

## Method 1: ALB with Auth0 Setup

### Prerequisites

- Auth0 account with admin access
- Custom domain configured in terraform.tfvars
- Lambda portal deployed

### Step 1: Create Auth0 Application

1. Log into Auth0 Dashboard
2. **Applications** → **Create Application**
3. Select **Regular Web Application**
4. Click **Create**

Configuration:
```
App Name: SageMaker Studio Portal
Grant Type: ✓ Authorization Code
Sign-in redirect URI: https://analysis.yourcompany.com/oauth2/idpresponse
Sign-out redirect URI: https://analysis.yourcompany.com
Allowed Callback URLs: (see Auth0 settings)
```

5. **Save** and note:
   - Client ID
   - Client Secret

### Step 2: Configure Terraform Variables

Add to `terraform.tfvars`:

```hcl
# Enable Auth0 authentication
enable_auth0_auth = true

# Okta configuration (from Step 1)
auth0_issuer_url    = "https://dev-12345678.us.auth0.com/oauth"
auth0_client_id     = "AbCdEfGhIjKlMnOpQrSt1234567890"
auth0_client_secret = "your-client-secret-here"

# Authorization endpoint (from Auth0 app settings)
auth0_authorization_endpoint = "https://dev-12345678.us.auth0.com/authorize"
auth0_token_endpoint        = "https://dev-12345678.us.auth0.com/token"
auth0_user_info_endpoint    = "https://dev-12345678.us.auth0.com/userinfo"
```

### Step 3: Deploy Okta Integration

```bash
# Apply Terraform changes
terraform apply

# Verify ALB listener has authentication action
aws elbv2 describe-listeners \
  --load-balancer-arn $(terraform output -raw alb_arn) \
  --query 'Listeners[?Port==`443`].DefaultActions'
```

### Step 4: Test Authentication Flow

1. Open browser (incognito/private mode)
2. Navigate to: `https://analysis.yourcompany.com`
3. You'll be redirected to Auth0 login
4. Enter Auth0 credentials
5. After authentication, you'll see the portal
6. Click "Launch Studio"
7. You're in SageMaker Studio!

### How It Works (Method 1)

```
1. User → https://analysis.yourcompany.com
   ↓
2. ALB checks authentication cookie
   ↓ (not authenticated)
3. ALB → Redirect to Okta
   ↓
4. User logs in to Okta
   ↓
5. Okta → Redirect back with authorization code
   ↓
6. ALB → Exchange code for token (automatic)
   ↓
7. ALB → Forward request to Lambda with headers:
   - x-amzn-oidc-identity: user@company.com
   - x-amzn-oidc-data: (JWT with user claims)
   ↓
8. Lambda → Extract user email
   ↓
9. Lambda → Create presigned URL for user's profile
   ↓
10. User → Redirected to SageMaker Studio
```

## Method 2: IAM Identity Center + Okta SAML Setup

See `OKTA_SETUP.md` for detailed SAML configuration.

**Key Integration Points:**

1. **Okta SAML App** → AWS IAM Identity Center
2. **IAM Permission Sets** → Terraform creates these (sso.tf)
3. **User Groups** → Assigned via IAM Identity Center Console
4. **Lambda Portal** → Works with SSO auth mode

### Quick Setup (Method 2)

```bash
# 1. Enable IAM Identity Center
aws organizations enable-aws-service-access \
  --service-principal sso.amazonaws.com

# 2. Get SSO details
aws sso-admin list-instances

# 3. Add to terraform.tfvars
echo 'enable_sso = true' >> terraform.tfvars
echo 'sso_instance_arn = "arn:aws:sso:::instance/ssoins-..."' >> terraform.tfvars
echo 'sso_identity_store_id = "d-..."' >> terraform.tfvars

# 4. Configure Okta SAML (see OKTA_SETUP.md)

# 5. Deploy
terraform apply
```

## Lambda Code for Okta Integration

The Lambda function automatically handles both authentication methods:

### ALB Authentication Headers

When using ALB with Auth0, Lambda receives:

```python
{
    "headers": {
        "x-amzn-oidc-identity": "user@company.com",
        "x-amzn-oidc-data": "eyJraWQ...JWT_TOKEN",
        "x-amzn-oidc-accesstoken": "access_token_value"
    }
}
```

### Enhanced Lambda Handler

The Lambda automatically extracts user identity:

```python
def get_user_from_alb_headers(event):
    """Extract authenticated user from ALB headers"""
    headers = event.get('headers', {})
    
    # Auth0 via ALB
    user_email = headers.get('x-amzn-oidc-identity')
    
    if user_email:
        # Convert email to user profile name
        # user@company.com → user-company-com
        return user_email.replace('@', '-').replace('.', '-')
    
    return DEFAULT_USER_PROFILE
```

This is already implemented in the portal Lambda!

## User Profile Management

### Automatic Profile Creation

SageMaker Studio automatically creates user profiles on first access when using SSO mode.

**With Okta + SSO:**
- User logs in via Okta
- Accesses custom domain
- Lambda uses user's email to determine profile
- SageMaker creates profile automatically (first time)
- Subsequent logins use existing profile

**Profile Naming Convention:**
```
Email: jane.doe@company.com
Profile: jane-doe-company-com
```

### Manual Profile Creation (Optional)

If using ALB OIDC without SSO mode:

```bash
# Create user profile for specific Okta user
aws sagemaker create-user-profile \
  --domain-id $(terraform output -raw sagemaker_domain_id) \
  --user-profile-name "jane-doe-company-com" \
  --user-settings '{
    "ExecutionRole": "'$(terraform output -raw sagemaker_execution_role_arn)'"
  }'
```

## Configuration Comparison

| Feature | ALB OIDC | IAM Identity Center + SAML |
|---------|----------|----------------------------|
| Setup Complexity | Simple | Moderate |
| Setup Time | 15-20 min | 30-45 min |
| SAML Required | No | Yes |
| Multi-Account | No | Yes |
| Cost | $0 extra | $0 extra |
| Session Management | ALB automatic | AWS SSO |
| User Profile Creation | Manual or automatic | Automatic |
| Lambda Integration | Direct (headers) | Indirect (assumes role) |
| Best For | Single account, quick setup | Enterprise, multi-account |

## Terraform Variables Reference

### ALB OIDC Variables

```hcl
# Enable Okta authentication via ALB
enable_auth0_auth = true

# Auth0 Configuration
auth0_issuer_url             = "https://dev-12345678.us.auth0.com/oauth"
auth0_client_id              = "0oa..."
auth0_client_secret          = "..."
auth0_authorization_endpoint = "https://dev-12345678.us.auth0.com/authorize"
auth0_token_endpoint         = "https://dev-12345678.us.auth0.com/token"
auth0_user_info_endpoint     = "https://dev-12345678.us.auth0.com/userinfo"
```

### IAM Identity Center + SAML Variables

```hcl
# Enable SSO mode
enable_sso = true

# AWS SSO configuration
sso_instance_arn      = "arn:aws:sso:::instance/ssoins-..."
sso_identity_store_id = "d-..."

# Okta SAML (configure in IAM Identity Center Console)
# No Terraform variables needed - configured via AWS Console
```

## Testing Your Integration

### Test 1: Authentication Flow

```bash
# 1. Clear browser cookies/use incognito
# 2. Access custom domain
curl -I https://analysis.yourcompany.com

# Expected: 302 redirect to Okta if using ALB OIDC
# Expected: 200 OK if using SSO (auth happens in SageMaker)
```

### Test 2: User Identity Extraction

```bash
# Check CloudWatch logs for Lambda
aws logs tail /aws/lambda/sagemaker-portal --follow

# Look for log entries showing user identity:
# "User from ALB: user@company.com"
```

### Test 3: End-to-End

1. Log in via Okta
2. Click "Launch Studio"
3. Verify you're redirected to Studio
4. Check user profile matches your Okta identity:

```bash
aws sagemaker list-user-profiles \
  --domain-id $(terraform output -raw sagemaker_domain_id)
```

## Security Considerations

### Session Management

**ALB OIDC:**
- Session cookies managed by ALB
- Default timeout: 7 days
- Configurable via `session_timeout` variable

**IAM Identity Center:**
- Session managed by AWS SSO
- Default timeout: 8 hours
- Configured in IAM Identity Center settings

### Token Security

- ✅ All tokens transmitted over HTTPS only
- ✅ ALB validates JWT tokens automatically
- ✅ Lambda receives verified user identity
- ✅ No token handling in application code

### Access Control

**ALB OIDC:**
- Control via Auth0 role assignments
- Optional: Add ALB rules for group-based routing

**IAM Identity Center:**
- Control via IAM permission sets
- Fine-grained AWS resource permissions

## Troubleshooting

### Issue: Redirected to Okta but access denied

**Cause:** User not assigned to Auth0 application

**Solution:**
```
Auth0 Dashboard → Applications → SageMaker Studio Portal
→ Assignments → Assign user/group
```

### Issue: "User profile not found"

**Cause:** Profile doesn't exist yet

**Solution 1 (SSO mode):**
```bash
# Profile created automatically on first Studio access
# User must visit SageMaker Console first
```

**Solution 2 (ALB OIDC):**
```bash
# Create profile manually
aws sagemaker create-user-profile \
  --domain-id $(terraform output -raw sagemaker_domain_id) \
  --user-profile-name "user-email-com" \
  --user-settings '{"ExecutionRole": "'$(terraform output -raw sagemaker_execution_role_arn)'"}'
```

### Issue: Authentication loop

**Cause:** Incorrect redirect URI in Okta

**Solution:**
Verify redirect URI in Okta exactly matches:
```
https://analysis.yourcompany.com/oauth2/idpresponse
```

### Issue: Lambda can't extract user identity

**Cause:** ALB authentication not configured

**Solution:**
```bash
# Verify ALB listener has authentication action
terraform apply

# Check logs
aws logs tail /aws/lambda/sagemaker-portal --follow
```

## Cost Impact

Adding Okta authentication has **zero additional AWS cost**:

- ✅ ALB authentication: Included in ALB pricing
- ✅ Lambda: Same cost (~$1/month)
- ✅ IAM Identity Center: Free
- ✅ No additional services

**Okta Cost:** Depends on your Okta plan (external to AWS)

## Migration Path

### Already Using IAM Mode?

Migrate to Okta authentication:

```bash
# 1. Choose method (ALB OIDC recommended for simplicity)

# 2. Configure Auth0 app

# 3. Update terraform.tfvars
enable_auth0_auth = true
# Add Okta variables

# 4. Apply changes
terraform apply

# 5. Test with one user

# 6. Roll out to team
```

### Already Using SSO Mode?

Your setup already supports Okta! Just configure the SAML connection in IAM Identity Center (see OKTA_SETUP.md).

## Example Configurations

### Example 1: Small Team (ALB OIDC)

```hcl
# terraform.tfvars
domain_name            = "sleetgale"
enable_custom_domain   = true
custom_domain_name     = "analysis.yourcompany.com"
route53_zone_id        = "Z1234567890ABC"

# Auth0
enable_auth0_auth             = true
auth0_issuer_url              = "https://dev-12345678.us.auth0.com/oauth"
auth0_client_id               = "AbCdEfGhIjKlMnOpQrSt1234567890"
auth0_client_secret           = "secret-value"
auth0_authorization_endpoint  = "https://dev-12345678.us.auth0.com/authorize"
auth0_token_endpoint          = "https://dev-12345678.us.auth0.com/token"
auth0_user_info_endpoint      = "https://dev-12345678.us.auth0.com/userinfo"
auth0_session_timeout         = 604800  # 7 days
```

### Example 2: Enterprise (IAM Identity Center + SAML)

```hcl
# terraform.tfvars
domain_name            = "sleetgale"
enable_custom_domain   = true
custom_domain_name     = "analysis.yourcompany.com"
route53_zone_id        = "Z1234567890ABC"

# SSO with Okta SAML
enable_sso               = true
sso_instance_arn         = "arn:aws:sso:::instance/ssoins-1234567890abcdef"
sso_identity_store_id    = "d-1234567890"
```

Then configure Okta SAML in IAM Identity Center Console (one-time setup).

## Summary

### ✅ YES - Okta Integration Works!

The Lambda portal solution is **fully compatible** with Okta:

1. **ALB OIDC Method** (Recommended)
   - Direct integration
   - 15-minute setup
   - Perfect for single account

2. **IAM Identity Center + SAML Method**
   - Enterprise-grade
   - 30-minute setup
   - Multi-account support

### Benefits of Okta + Lambda Portal

- ✅ **Single Sign-On** - Users authenticate once
- ✅ **Low Cost** - $0 AWS overhead, ~$1/month Lambda
- ✅ **Automatic** - ALB handles all auth logic
- ✅ **Secure** - HTTPS, verified tokens, no password storage
- ✅ **Scalable** - Lambda scales with user load
- ✅ **Centralized** - Manage users in Okta

### Next Steps

1. Choose integration method (ALB OIDC recommended)
2. Follow setup instructions above
3. Test with one user
4. Roll out to team
5. Enjoy secure, cost-effective SageMaker access!

## Support Resources

- **ALB Authentication**: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-authenticate-users.html
- **Auth0**: https://developer.okta.com/docs/guides/implement-grant-type/authcode/main/
- **IAM Identity Center**: https://docs.aws.amazon.com/singlesignon/
- **Okta SAML**: See `OKTA_SETUP.md`
