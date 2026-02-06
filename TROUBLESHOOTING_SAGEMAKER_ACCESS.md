# Troubleshooting SageMaker Access Issues

## Issues Reported

1. **SageMaker Direct URL**: `https://d-d4ujiazahn5b.studio.us-east-1.sagemaker.aws` shows "Invalid or Expired Auth Token"
2. **Custom Domain**: `analysis.savantpraxis.com` shows "503 Service Temporarily Unavailable"

## Root Cause Analysis

### Issue 1: Invalid or Expired Auth Token (SageMaker Direct URL)

This is **NORMAL behavior** for SageMaker Studio. The error message is misleading - it's not actually an error.

**What's Happening:**
- SageMaker Studio URLs require a presigned URL that includes authentication tokens
- These presigned URLs expire after a short time (typically 5-15 minutes)
- The URL `d-d4ujiazahn5b.studio.us-east-1.sagemaker.aws` is the base domain URL
- You need to generate a fresh presigned URL to access SageMaker Studio

**This is NOT a problem with your infrastructure!**

### Issue 2: 503 Service Temporarily Unavailable (Custom Domain)

This indicates that the Application Load Balancer (ALB) cannot reach the SageMaker backend. This is a **REAL PROBLEM** that needs to be fixed.

**Possible Causes:**
1. No target IPs registered in the ALB target group
2. Health checks failing
3. SageMaker domain not accessible from ALB
4. Security group configuration blocking traffic
5. Target group misconfigured

## Diagnosis Commands

### Check SageMaker Domain Status

```bash
# Get domain ID from Terraform
terraform output sagemaker_domain_id

# Check domain status
aws sagemaker describe-domain \
  --domain-id d-d4ujiazahn5b \
  --region us-east-1 \
  --query 'Status'

# Check if domain is in VPC mode
aws sagemaker describe-domain \
  --domain-id d-d4ujiazahn5b \
  --region us-east-1 \
  --query '[AppNetworkAccessType, VpcId, SubnetIds]'
```

### Check ALB and Target Group Status

```bash
# List ALBs
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `sleetgale`)].LoadBalancerArn'

# Get target group ARN
aws elbv2 describe-target-groups \
  --region us-east-1 \
  --query 'TargetGroups[?contains(TargetGroupName, `sleetgale`)].TargetGroupArn'

# Check target health (use ARN from above)
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region us-east-1

# Check target group attributes
aws elbv2 describe-target-group-attributes \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region us-east-1
```

### Check DNS Resolution

```bash
# Check if custom domain resolves to ALB
dig analysis.savantpraxis.com

# Check ALB DNS name
nslookup analysis.savantpraxis.com

# Test ALB endpoint directly
curl -I https://analysis.savantpraxis.com
```

## Root Cause: ALB Target Group Configuration Issue

### The Problem

Looking at the Terraform configuration in `ssl.tf`, the ALB is configured with a target group that uses `target_type = "ip"` (line 145). However, **there are NO target registrations configured in the Terraform code**.

```terraform
resource "aws_lb_target_group" "sagemaker_tg" {
  count       = var.enable_custom_domain ? 1 : 0
  name        = "${var.domain_name}-tg"
  port        = 443
  protocol    = "HTTPS"
  vpc_id      = aws_vpc.sagemaker_vpc.id
  target_type = "ip"  # <-- IP-based targets
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTPS"
    timeout             = 5
    unhealthy_threshold = 2
  }
}
```

**Missing:** There's no `aws_lb_target_group_attachment` resource to register SageMaker Studio as a target!

### Why This Happens

The architecture has a fundamental issue:

1. **SageMaker Studio is NOT a traditional web service** that can be accessed via an ALB
2. **SageMaker Studio URLs are dynamic** and change with each session
3. **SageMaker Studio requires presigned URLs** with authentication tokens
4. **You cannot put SageMaker Studio behind an ALB** in the traditional way

### The Misconception

The current infrastructure assumes you can:
- Point an ALB at SageMaker Studio
- Access SageMaker through a custom domain like `analysis.savantpraxis.com`

**This is NOT how SageMaker Studio works!**

## How SageMaker Studio Actually Works

### Access Methods

**Method 1: AWS Console (Recommended)**
1. Go to AWS Console → SageMaker → Domains
2. Click on your domain: `d-d4ujiazahn5b`
3. Click on a user profile
4. Click "Launch" → "Studio"
5. AWS generates a fresh presigned URL
6. You're redirected to SageMaker Studio

**Method 2: AWS CLI**
```bash
# Create presigned URL
aws sagemaker create-presigned-domain-url \
  --domain-id d-d4ujiazahn5b \
  --user-profile-name default-user \
  --region us-east-1 \
  --query 'AuthorizedUrl'
```

**Method 3: AWS SDK**
Use the AWS SDK in your application to generate presigned URLs programmatically.

### Why Custom Domains Don't Work for SageMaker Studio

SageMaker Studio is a managed service with:
- **Dynamic URLs** that change per session
- **Built-in authentication** via IAM or SSO
- **WebSocket connections** for real-time collaboration
- **Session management** that requires AWS infrastructure

You **cannot** simply proxy it through an ALB with a custom domain.

## Solutions and Workarounds

### Option 1: Remove Custom Domain for SageMaker Access (Recommended)

**Understanding:**
- The custom domain infrastructure (ALB, certificates, DNS) was likely intended for a different use case
- SageMaker Studio should be accessed directly via AWS-generated URLs
- Custom domains are more suitable for deployed models/endpoints, not Studio itself

**Action:**
- Keep using SageMaker Studio via AWS Console or CLI
- Use the domain-specific URL: `https://d-d4ujiazahn5b.studio.us-east-1.sagemaker.aws`
- Generate fresh presigned URLs as needed

### Option 2: Use Custom Domain for SageMaker Endpoints (Not Studio)

If you want to use `analysis.savantpraxis.com`, use it for:
- **SageMaker Model Endpoints** (real-time inference)
- **SageMaker Batch Transform Jobs**
- **Custom web application** that calls SageMaker APIs

**Example Architecture:**
```
Custom Domain (analysis.savantpraxis.com)
    ↓
  ALB
    ↓
  Your Web App (EC2/ECS/Lambda)
    ↓
  SageMaker APIs/Endpoints
```

### Option 3: Build a Portal with Custom Domain

Create a web portal at `analysis.savantpraxis.com` that:
1. Authenticates users
2. Calls `create-presigned-domain-url` API
3. Redirects users to the presigned URL
4. Manages user sessions

**Components needed:**
```
analysis.savantpraxis.com
    ↓
  ALB
    ↓
  Web Application (Flask/Django/Node.js)
    ├── User Authentication
    ├── AWS SDK integration
    └── Presigned URL generation
    ↓
  Redirect to SageMaker Studio URL
```

### Option 4: VPC Endpoint for Private Access

If you want private access to SageMaker Studio:

```terraform
resource "aws_vpc_endpoint" "sagemaker_studio" {
  vpc_id              = aws_vpc.sagemaker_vpc.id
  service_name        = "aws.sagemaker.${var.aws_region}.studio"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.sagemaker_subnets[*].id
  security_group_ids  = [aws_security_group.sagemaker_sg.id]
  private_dns_enabled = true
}
```

But this still requires presigned URLs!

## Immediate Actions to Take

### 1. Understand Current Infrastructure Purpose

**Question:** What is the custom domain `analysis.savantpraxis.com` intended for?

- If for **SageMaker Studio access**: Not possible with standard ALB setup
- If for **deployed ML models**: Need to configure endpoints
- If for **custom web portal**: Need to build the web application

### 2. Access SageMaker Studio Properly

**For now, use the correct access method:**

```bash
# Generate a fresh presigned URL
aws sagemaker create-presigned-domain-url \
  --domain-id d-d4ujiazahn5b \
  --user-profile-name default-user \
  --region us-east-1 \
  --session-expiration-duration-in-seconds 3600
```

Or use the AWS Console as described above.

### 3. Fix or Remove ALB Infrastructure

**Option A: Remove unused ALB (if not needed)**

If the custom domain isn't being used for anything:

```bash
# Disable custom domain in your terraform.tfvars
enable_custom_domain = false

# Apply changes
terraform apply
```

**Option B: Repurpose ALB for actual web service**

If you want to use the custom domain:
1. Deploy a web application behind the ALB
2. Have that application generate presigned URLs
3. Use it as a portal to access SageMaker

### 4. Update DNS (if needed)

If `analysis.savantpraxis.com` should point to something else:

```bash
# Check current DNS
aws route53 list-resource-record-sets \
  --hosted-zone-id Z05687192QVMDJJL9QM6A \
  --query "ResourceRecordSets[?Name=='analysis.savantpraxis.com.']"
```

## What Went Wrong: Summary

### Root Cause
The infrastructure was set up with an ALB and custom domain expecting to proxy SageMaker Studio, but:

1. **SageMaker Studio cannot be proxied** through an ALB traditionally
2. **No backend targets were registered** in the ALB target group
3. **The 503 error is expected** because the ALB has no healthy targets

### The Confusion
- The error "Invalid or Expired Auth Token" on the SageMaker URL is **normal behavior**
- The 503 on the custom domain is because **the ALB has nothing to forward to**
- These are two separate issues with different solutions

### What to Do
1. **For SageMaker Studio access:** Use AWS Console or CLI to generate presigned URLs
2. **For custom domain:** Decide what it should actually be used for
3. **Fix the architecture:** Either remove the ALB or deploy a proper backend service

## Next Steps

### Immediate (To Access SageMaker Now)

```bash
# Use AWS Console
# OR generate presigned URL:
aws sagemaker create-presigned-domain-url \
  --domain-id d-d4ujiazahn5b \
  --user-profile-name default-user \
  --region us-east-1
```

### Short Term (Fix the Custom Domain)

Choose one:
1. Remove custom domain infrastructure (not needed for Studio)
2. Build a web portal at `analysis.savantpraxis.com`
3. Use the domain for SageMaker endpoints instead

### Long Term (Proper Architecture)

Document and implement the intended architecture:
- What is `analysis.savantpraxis.com` supposed to do?
- Do you need it at all?
- What services should be behind it?

## Additional Resources

- [SageMaker Studio Access Control](https://docs.aws.amazon.com/sagemaker/latest/dg/studio-ui.html)
- [Creating Presigned URLs](https://docs.aws.amazon.com/sagemaker/latest/dg/studio-updated-jl-api.html)
- [SageMaker VPC Configuration](https://docs.aws.amazon.com/sagemaker/latest/dg/studio-notebooks-and-internet-access.html)
- [ALB Target Groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)

## Checking Your Specific Setup

Run these commands to get specific information about your deployment:

```bash
# 1. Get SageMaker domain details
aws sagemaker describe-domain --domain-id d-d4ujiazahn5b --region us-east-1

# 2. List user profiles
aws sagemaker list-user-profiles --domain-id d-d4ujiazahn5b --region us-east-1

# 3. Create presigned URL for a specific user
aws sagemaker create-presigned-domain-url \
  --domain-id d-d4ujiazahn5b \
  --user-profile-name <USER_PROFILE_NAME> \
  --region us-east-1

# 4. Check ALB target health
# First get the target group ARN
aws elbv2 describe-target-groups --region us-east-1 \
  | grep -A 5 sleetgale

# Then check health with that ARN
aws elbv2 describe-target-health \
  --target-group-arn <ARN_FROM_ABOVE> \
  --region us-east-1

# 5. Check if any targets are registered
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region us-east-1 \
  --query 'TargetHealthDescriptions[*].[Target.Id, TargetHealth.State]'
```

## Expected Output

When you check the target health, you'll likely see:
- **Empty list** - No targets registered (explains the 503)
- **Or targets in "unhealthy" state** - Can't reach SageMaker

This confirms the ALB has nowhere to forward traffic, causing the 503 error.
