# Quick Reference Card

## Sleetgale - SageMaker Studio Infrastructure

### Getting Started

```bash
# Clone repository
git clone https://github.com/thestrugglingblack/sleetgale.git
cd sleetgale

# Initialize Terraform
terraform init

# Deploy with defaults (IAM mode)
terraform apply
```

### Deployment Modes

| Mode | Variables Required | Monthly Cost | Use Case |
|------|-------------------|--------------|----------|
| **Basic IAM** | None (defaults) | ~$0 | Development & testing |
| **Custom Domain** | `enable_custom_domain=true`<br/>`custom_domain_name` | ~$16-20 | Branded access URL |
| **SSO (Okta)** | `enable_sso=true`<br/>`sso_instance_arn`<br/>`sso_identity_store_id`<br/>`okta_idp_metadata_url` | ~$0 | Enterprise authentication |
| **Full Enterprise** | Both Custom Domain & SSO | ~$16-20 | Production deployment |

### Essential Commands

```bash
# Validate configuration
terraform validate

# Preview changes
terraform plan

# Apply changes
terraform apply

# View outputs
terraform output

# Destroy infrastructure
terraform destroy
```

### Quick Setup Examples

#### Basic Setup (Default)
```bash
terraform apply
# Access via: terraform output sagemaker_domain_url
```

#### With Custom Domain
```bash
cat > terraform.tfvars << EOF
enable_custom_domain = true
custom_domain_name   = "sagemaker.example.com"
route53_zone_id      = "Z1234567890ABC"
EOF

terraform apply
# Access via: https://sagemaker.example.com
```

#### With SSO
```bash
# First, get SSO details
aws sso-admin list-instances

cat > terraform.tfvars << EOF
enable_sso              = true
sso_instance_arn        = "arn:aws:sso:::instance/ssoins-..."
sso_identity_store_id   = "d-..."
okta_idp_metadata_url   = "https://dev-....okta.com/app/.../sso/saml/metadata"
EOF

terraform apply
# Complete SSO setup in IAM Identity Center Console
```

### Key Variables

```hcl
# Basic
aws_region  = "us-east-1"
domain_name = "sleetgale"

# Custom Domain
enable_custom_domain = true
custom_domain_name   = "sagemaker.example.com"
route53_zone_id      = "Z1234567890ABC"

# SSO
enable_sso              = true
sso_instance_arn        = "arn:aws:sso:::instance/ssoins-..."
sso_identity_store_id   = "d-..."
okta_idp_metadata_url   = "https://dev-....okta.com/app/.../metadata"
```

### Documentation Index

| Document | Purpose |
|----------|---------|
| **README.md** | Overview, features, quick start |
| **SETUP.md** | Detailed step-by-step setup guide |
| **OKTA_SETUP.md** | Okta SAML configuration reference |
| **ARCHITECTURE.md** | Architecture diagrams & flows |
| **IMPLEMENTATION_SUMMARY.md** | Complete implementation details |

### Common Tasks

#### Get AWS SSO Details
```bash
# Instance ARN
aws sso-admin list-instances --query 'Instances[0].InstanceArn' --output text

# Identity Store ID
aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text
```

#### Get Route 53 Zone ID
```bash
aws route53 list-hosted-zones --query 'HostedZones[?Name==`example.com.`].Id' --output text
```

#### Check SageMaker Domain
```bash
aws sagemaker describe-domain --domain-id $(terraform output -raw sagemaker_domain_id)
```

#### View Terraform State
```bash
terraform show
terraform state list
```

### Troubleshooting

#### Certificate Validation Stuck
```bash
# Check DNS records
dig _validation.sagemaker.example.com

# Wait up to 30 minutes for DNS propagation
```

#### SSO Access Denied
```bash
# Verify permission sets assigned
aws sso-admin list-account-assignments \
  --instance-arn "arn:aws:sso:::instance/..." \
  --account-id $(aws sts get-caller-identity --query Account --output text)
```

#### Domain Creation Failed
```bash
# Enable debug logging
TF_LOG=DEBUG terraform apply

# Check CloudTrail for errors
aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::SageMaker::Domain
```

### Cost Breakdown

```
Base Infrastructure:     $0/month
  └─ Pay only for usage: ~$0.05/hour (ml.t3.medium when running)

Optional: Custom Domain: ~$16-20/month
  ├─ ALB:                ~$16/month
  ├─ Route 53 Zone:      $0.50/month
  └─ ACM Certificate:    Free

Optional: SSO:           $0/month
  ├─ IAM Identity Center: Free
  └─ Okta:               External subscription
```

### Security Best Practices

✅ Use SSO for production environments  
✅ Enable MFA in Okta  
✅ Use custom domain with HTTPS  
✅ Regularly review CloudTrail logs  
✅ Implement least-privilege IAM policies  
✅ Keep Terraform state secure  
✅ Use separate AWS accounts for dev/prod  

### Support

- 📖 Full docs in repository
- 🐛 GitHub Issues for bugs
- 💬 Discussions for questions
- 📧 CloudTrail logs for AWS errors

### Version

- **Terraform**: >= 1.0
- **AWS Provider**: ~> 5.0
- **Last Updated**: 2024

---

**Quick Links:**
- [README.md](README.md) - Start here
- [SETUP.md](SETUP.md) - Step-by-step guide
- [OKTA_SETUP.md](OKTA_SETUP.md) - Okta configuration
- [ARCHITECTURE.md](ARCHITECTURE.md) - Diagrams
