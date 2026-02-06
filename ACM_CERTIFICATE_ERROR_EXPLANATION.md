# ACM Certificate Error - Explanation and Fix

## What's Happening

You're encountering an error when Terraform tries to create an HTTPS listener on your Application Load Balancer (ALB). The error message is:

```
Error: creating ELBv2 Listener: api error UnsupportedCertificate: 
The certificate 'arn:aws:acm:us-east-1:378737770782:certificate/dddb4eea-302b-4b2f-99de-65bddc814381' 
must have a fully-qualified domain name, a supported signature, and a supported key size.
```

### Root Cause

The ACM (AWS Certificate Manager) certificate was created successfully, but it's **not validated yet**. AWS requires ACM certificates to be validated before they can be used with an Application Load Balancer.

Here's what's happening in your Terraform code:

1. **ACM Certificate Creation** (line 36-48 in ssl.tf):
   - Terraform creates an ACM certificate for `var.custom_domain_name` (e.g., `sagemaker.savantpraxis.com`)
   - The certificate is created with DNS validation method

2. **DNS Validation Records** (line 51-66 in ssl.tf):
   - Terraform creates the DNS validation records in Route 53
   - These CNAME records prove you own the domain

3. **Certificate Validation** (line 69-73 in ssl.tf):
   - Terraform waits for the certificate to be validated
   - This is the `aws_acm_certificate_validation` resource

4. **ALB HTTPS Listener** (line 165-176 in ssl.tf):
   - Terraform tries to attach the certificate to the ALB listener
   - **This fails because the certificate validation hasn't completed**

### Why the Certificate Isn't Validated

The certificate validation process requires:
1. DNS records to be created in Route 53 ✅
2. DNS propagation to complete (can take 5-30 minutes) ⏳
3. AWS ACM to verify the DNS records ⏳
4. Certificate status to change from "PENDING_VALIDATION" to "ISSUED" ⏳

The error occurs because Terraform is trying to use the certificate **before step 4 completes**.

## How to Check Certificate Status

Run these AWS CLI commands to check your certificate status:

```bash
# List all certificates
aws acm list-certificates --region us-east-1

# Get details about your specific certificate
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:378737770782:certificate/dddb4eea-302b-4b2f-99de-65bddc814381 \
  --region us-east-1
```

Look for the `Status` field:
- **PENDING_VALIDATION**: Certificate is waiting for DNS validation (not ready yet)
- **ISSUED**: Certificate is validated and ready to use ✅
- **FAILED**: Validation failed (needs investigation)

You can also check in the AWS Console:
1. Go to AWS Console → Certificate Manager (ACM) → us-east-1 region
2. Find your certificate for `sagemaker.savantpraxis.com`
3. Check the status

## What You Need to Fix

### Option 1: Wait and Retry (Recommended)

The certificate validation is likely still in progress. Simply **wait 10-30 minutes** and try again:

```bash
# Wait for DNS propagation and certificate validation
# Check certificate status periodically
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:378737770782:certificate/dddb4eea-302b-4b2f-99de-65bddc814381 \
  --region us-east-1 \
  --query 'Certificate.Status'

# When status is "ISSUED", retry Terraform
terraform apply
```

### Option 2: Verify DNS Records

If waiting doesn't help, verify the DNS validation records were created correctly:

```bash
# Check what Route 53 records were created
aws route53 list-resource-record-sets \
  --hosted-zone-id Z05687192QVMDJJL9QM6A \
  --query "ResourceRecordSets[?Type=='CNAME']"

# Verify DNS propagation externally
dig _<validation-string>.sagemaker.savantpraxis.com CNAME
```

The validation CNAME records should:
- Be present in your Route 53 hosted zone
- Match the validation records shown in ACM console
- Be resolvable via DNS queries

### Option 3: Manual DNS Validation (If Using External DNS)

If your Route 53 zone nameservers aren't properly delegated:

1. **Get the validation CNAME records from ACM Console**:
   - AWS Console → Certificate Manager → Your Certificate
   - Copy the CNAME name and value

2. **Add the CNAME record in your DNS provider** (if not using Route 53 as primary DNS)

3. **Wait for DNS propagation** (5-30 minutes)

4. **Wait for ACM validation** (another 5-30 minutes)

5. **Retry Terraform**

### Option 4: Use Existing Certificate

If you already have a validated certificate:

```hcl
# In your terraform.tfvars or when running terraform apply
enable_custom_domain = true
custom_domain_name   = "sagemaker.savantpraxis.com"
route53_zone_id      = "Z05687192QVMDJJL9QM6A"
certificate_arn      = "arn:aws:acm:us-east-1:378737770782:certificate/YOUR-VALIDATED-CERT-ARN"
```

This skips certificate creation and uses your existing validated certificate.

## Understanding the Terraform Dependencies

Your `ssl.tf` has these resources in order:

```
1. aws_acm_certificate.sagemaker_cert
   ↓
2. aws_route53_record.cert_validation
   ↓
3. aws_acm_certificate_validation.sagemaker_cert
   ↓
4. aws_lb.sagemaker_alb
   ↓
5. aws_lb_listener.https (FAILS HERE)
```

The issue is that `aws_acm_certificate_validation` resource **initiates** the validation but doesn't always **wait long enough** for AWS to complete validation if DNS propagation is slow.

## Troubleshooting Steps

### Step 1: Check Current Certificate Status

```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:378737770782:certificate/dddb4eea-302b-4b2f-99de-65bddc814381 \
  --region us-east-1
```

### Step 2: Check DNS Records

```bash
# List all records in your hosted zone
aws route53 list-resource-record-sets \
  --hosted-zone-id Z05687192QVMDJJL9QM6A

# Check if validation records are created
aws route53 list-resource-record-sets \
  --hosted-zone-id Z05687192QVMDJJL9QM6A \
  --query "ResourceRecordSets[?contains(Name, '_')]"
```

### Step 3: Verify Domain Configuration

```bash
# Check if your domain is configured correctly
dig sagemaker.savantpraxis.com

# Check nameservers
dig NS savantpraxis.com
```

### Step 4: Check Route 53 Hosted Zone

```bash
# Get nameservers for your hosted zone
aws route53 get-hosted-zone --id Z05687192QVMDJJL9QM6A
```

Ensure these nameservers are configured at your domain registrar.

## Common Issues and Solutions

### Issue 1: DNS Propagation Not Complete

**Symptoms**: Certificate status is "PENDING_VALIDATION" for a long time

**Solution**: 
- Wait longer (can take up to 30 minutes)
- Check DNS propagation: `dig _<validation-record>.sagemaker.savantpraxis.com CNAME`
- Verify nameservers are correct

### Issue 2: Wrong Hosted Zone

**Symptoms**: Validation records created in wrong zone

**Solution**:
- Verify `route53_zone_id` variable points to the correct zone for `savantpraxis.com`
- The zone should be for the parent domain, not subdomain

### Issue 3: Nameservers Not Delegated

**Symptoms**: DNS records don't resolve externally

**Solution**:
- Get nameservers from Route 53: `aws route53 get-hosted-zone --id Z05687192QVMDJJL9QM6A`
- Update your domain registrar to use these nameservers

### Issue 4: Certificate Already Exists

**Symptoms**: Terraform creates duplicate certificate

**Solution**:
- Delete the pending certificate in ACM console
- Run `terraform apply` again
- Or use the existing certificate ARN in variables

## Prevention for Next Time

To avoid this issue in future deployments:

1. **Ensure DNS is properly configured** before running Terraform
2. **Pre-create and validate the certificate** manually, then use `certificate_arn` variable
3. **Use separate Terraform runs**: 
   - First run: Create certificate and validation records
   - Wait for validation
   - Second run: Create ALB and listeners

## Recommended Action Plan

**Do this NOW:**

1. **Check certificate status**:
   ```bash
   aws acm describe-certificate \
     --certificate-arn arn:aws:acm:us-east-1:378737770782:certificate/dddb4eea-302b-4b2f-99de-65bddc814381 \
     --region us-east-1 \
     --query 'Certificate.Status'
   ```

2. **If status is "PENDING_VALIDATION"**:
   - Wait 15-30 minutes
   - Check again
   - When status is "ISSUED", run `terraform apply`

3. **If status is "FAILED"**:
   - Check DNS records are correct
   - Delete the certificate: `aws acm delete-certificate --certificate-arn <arn>`
   - Run `terraform apply` again

4. **If waiting doesn't help after 30 minutes**:
   - Verify DNS configuration (see Step 2-4 above)
   - Check nameserver delegation
   - Verify Route 53 hosted zone is correct

## Summary

**The error is NOT a bug in your Terraform code.** It's a timing issue where:
- ✅ The certificate was created successfully
- ✅ The DNS validation records were created
- ⏳ AWS hasn't finished validating the certificate yet
- ❌ Terraform tries to use the unvalidated certificate

**Solution**: Wait for certificate validation to complete (check status with AWS CLI), then re-run `terraform apply`.

## Need More Help?

If the certificate is stuck in PENDING_VALIDATION after 30 minutes:
1. Check the DNS troubleshooting steps above
2. Review [SETUP.md](SETUP.md) for DNS configuration
3. Check [IAM_PERMISSIONS.md](IAM_PERMISSIONS.md) if you're getting permission errors
4. Verify your `route53_zone_id` variable matches your actual Route 53 zone

The validation WILL complete once DNS is properly configured and propagated. Be patient! 🕐
