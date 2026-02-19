# Using Existing DNS and SSL Resources

This guide explains how to configure Terraform to use your **existing** Route53 hosted zone and ACM certificate, preventing any recreation or modification of these resources.

## Quick Summary

If you already have DNS and SSL configured, use this configuration:

```hcl
# terraform.tfvars
enable_custom_domain = true
custom_domain_name   = "analysis.yourcompany.com"

# Use EXISTING Route53 zone
create_route53_zone = false
route53_zone_id     = "Z1234567890ABC"  # YOUR existing zone ID

# Use EXISTING ACM certificate  
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

**Result:** Terraform will ONLY create one A record pointing to the ALB. Nothing else.

## Why This Matters

By default, if you don't specify `certificate_arn`, Terraform will:
1. ❌ Create a NEW ACM certificate
2. ❌ Add DNS validation records to your Route53 zone
3. ❌ Potentially conflict with existing certificates
4. ❌ Take 5-10 minutes for certificate validation

By specifying existing resources, Terraform will:
1. ✅ Use your existing ACM certificate
2. ✅ Use your existing Route53 zone
3. ✅ Only create ONE A record (custom_domain_name → ALB)
4. ✅ Deploy in under 2 minutes

## Step-by-Step Guide

### Step 1: Find Your Route53 Zone ID

```bash
# List all hosted zones
aws route53 list-hosted-zones

# Or filter by domain name
aws route53 list-hosted-zones \
  --query 'HostedZones[?Name==`yourcompany.com.`].[Id,Name]' \
  --output table
```

Example output:
```
Z1234567890ABC  yourcompany.com.
```

**Important:** Use the zone for your **base domain** (e.g., `yourcompany.com`), not a subdomain.

### Step 2: Find Your ACM Certificate ARN

```bash
# List certificates in us-east-1 (required for ALB)
aws acm list-certificates --region us-east-1

# Or filter by domain
aws acm list-certificates --region us-east-1 \
  --query 'CertificateSummaryList[?DomainName==`*.yourcompany.com`].[CertificateArn,DomainName]' \
  --output table
```

Example output:
```
arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012
*.yourcompany.com
```

**Important:** 
- Certificate MUST be in `us-east-1` region (ALB requirement)
- Certificate should cover your domain (exact match or wildcard)

### Step 3: Configure terraform.tfvars

Create or update `terraform.tfvars`:

```hcl
# Basic Configuration
aws_region   = "us-east-1"
environment  = "production"
domain_name  = "sleetgale"

# Custom Domain - Use EXISTING Resources
enable_custom_domain = true
custom_domain_name   = "analysis.yourcompany.com"

# EXISTING Route53 Zone
create_route53_zone = false  # Don't create a new zone
route53_zone_id     = "Z1234567890ABC"  # YOUR zone ID from Step 1

# EXISTING ACM Certificate
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"  # YOUR cert ARN from Step 2

# Optional: Auth0 Authentication
enable_auth0        = true
auth0_domain        = "dev-12345678.us.auth0.com"
auth0_client_id     = "AbCdEfGhIjKlMnOpQrSt1234567890"
auth0_client_secret = "your-secret"
```

### Step 4: Verify Terraform Plan

Before applying, verify what Terraform will create:

```bash
terraform plan
```

**Expected resources (when using existing DNS/SSL):**
- ✅ `aws_route53_record.sagemaker_alb[0]` - ONE A record (create)
- ✅ `aws_lb.sagemaker_alb[0]` - Application Load Balancer (create)
- ✅ `aws_lb_listener.https[0]` - HTTPS listener (create)
- ✅ Other AWS resources (VPC, SageMaker, Lambda, etc.)

**Resources that should NOT appear:**
- ❌ `aws_route53_zone.custom_domain[0]` - Should NOT create
- ❌ `aws_acm_certificate.sagemaker_cert[0]` - Should NOT create
- ❌ `aws_route53_record.cert_validation` - Should NOT create
- ❌ `aws_acm_certificate_validation.sagemaker_cert[0]` - Should NOT create

If you see any of the ❌ resources, **STOP** and verify your configuration.

### Step 5: Deploy

```bash
terraform apply
```

Terraform will:
1. Create VPC, subnets, security groups
2. Create SageMaker Studio domain
3. Create Application Load Balancer
4. Create Lambda function for portal
5. Create ONE A record in your existing Route53 zone
6. Use your existing ACM certificate for HTTPS

**Deployment time:** ~3-5 minutes (instead of 10-15 minutes with new cert)

## What Gets Created vs. What Gets Used

### Resources Terraform Creates (When Using Existing DNS/SSL)

| Resource | Count | Description |
|----------|-------|-------------|
| Route53 A Record | 1 | Points custom_domain_name to ALB |
| Application Load Balancer | 1 | Handles HTTPS traffic |
| Target Group | 1 | Routes to Lambda |
| HTTPS Listener | 1 | Port 443, uses existing cert |
| HTTP Listener | 1 | Port 80, redirects to HTTPS |
| Security Group | 1 | Allows 80/443 inbound |
| Lambda Function | 1 | Portal application |
| VPC Resources | Multiple | VPC, subnets, route tables |
| SageMaker Domain | 1 | Studio environment |

### Resources Terraform Uses (Not Created)

| Resource | Source | Description |
|----------|--------|-------------|
| Route53 Hosted Zone | Existing | Your zone (via route53_zone_id) |
| ACM Certificate | Existing | Your cert (via certificate_arn) |

## Common Scenarios

### Scenario 1: I have a wildcard certificate

```hcl
# Your certificate: *.yourcompany.com
custom_domain_name = "analysis.yourcompany.com"
certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/..."  # Wildcard cert
```

✅ This works! Wildcard cert covers any subdomain.

### Scenario 2: I have a specific domain certificate

```hcl
# Your certificate: analysis.yourcompany.com
custom_domain_name = "analysis.yourcompany.com"
certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/..."  # Exact match
```

✅ This works! Certificate matches exactly.

### Scenario 3: Certificate in wrong region

```hcl
# Your certificate is in us-west-2
certificate_arn = "arn:aws:acm:us-west-2:123456789012:certificate/..."
```

❌ This will FAIL! ALB requires certificate in us-east-1.

**Solution:** Request a new certificate in us-east-1 or let Terraform create one.

### Scenario 4: I want Terraform to create the certificate

```hcl
# Leave certificate_arn empty
certificate_arn = ""

# Provide zone for DNS validation
route53_zone_id = "Z1234567890ABC"
```

⚠️ Terraform will create a NEW certificate and add validation records.

## Troubleshooting

### Error: Certificate validation timeout

**Cause:** Terraform tried to create a new certificate but validation failed.

**Solution:**
1. Provide existing `certificate_arn` to skip certificate creation
2. Or ensure `route53_zone_id` is correct for DNS validation

### Error: Zone ID not found

**Cause:** `route53_zone_id` is incorrect or zone doesn't exist.

**Solution:**
```bash
aws route53 list-hosted-zones
```

Verify the zone ID and update terraform.tfvars.

### Error: Certificate doesn't match domain

**Cause:** ACM certificate doesn't cover the `custom_domain_name`.

**Solution:**
- Use a wildcard certificate that covers the domain
- Or request a new certificate for the specific domain
- Or let Terraform create one (omit `certificate_arn`)

### Terraform wants to recreate the A record

**Cause:** The A record already exists in Route53.

**Solution:**
1. Import the existing record:
   ```bash
   terraform import 'aws_route53_record.sagemaker_alb[0]' Z1234567890ABC_analysis.yourcompany.com_A
   ```
2. Or delete the existing record and let Terraform create it

## Verification

After deployment, verify everything is working:

```bash
# Check DNS resolution
dig analysis.yourcompany.com

# Should return ALB address
nslookup analysis.yourcompany.com

# Test HTTPS (should show valid certificate)
curl -I https://analysis.yourcompany.com

# Access portal
open https://analysis.yourcompany.com
```

## Summary

**To prevent Terraform from recreating DNS and ACM resources:**

1. ✅ Set `create_route53_zone = false`
2. ✅ Provide `route53_zone_id` (your existing zone)
3. ✅ Provide `certificate_arn` (your existing cert in us-east-1)
4. ✅ Run `terraform plan` to verify
5. ✅ Only ONE Route53 A record should be created

**What Terraform will NOT touch:**
- ❌ Your Route53 hosted zone
- ❌ Your ACM certificate
- ❌ Other DNS records in your zone

**What Terraform will create:**
- ✅ One A record for custom_domain_name → ALB
- ✅ Application Load Balancer and related resources
- ✅ SageMaker and Lambda resources

This ensures your existing DNS and SSL infrastructure remains untouched while still enabling custom domain access to SageMaker Studio.
