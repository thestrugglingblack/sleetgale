# How to Access SageMaker Studio - Quick Guide

## TL;DR - What You Need to Know

### The "Invalid or Expired Auth Token" Error is NORMAL
- This is expected behavior for SageMaker Studio
- You need to generate a fresh presigned URL each time
- The URL expires after 5-15 minutes

### The "503 Service Unavailable" on analysis.savantpraxis.com is EXPECTED
- SageMaker Studio cannot be accessed through an ALB + custom domain
- The ALB has no backend targets registered
- This custom domain setup doesn't work for SageMaker Studio

## How to Access SageMaker Studio (The Right Way)

### Method 1: AWS Console (Easiest)

1. Go to: https://console.aws.amazon.com/sagemaker/
2. Click **Domains** in left sidebar
3. Click on domain: **d-d4ujiazahn5b**
4. Click on a user profile (e.g., "default-user")
5. Click **Launch** button → **Studio**
6. AWS generates a fresh URL and opens SageMaker Studio

**This is the recommended way!**

### Method 2: AWS CLI (For Automation)

```bash
# Generate presigned URL
aws sagemaker create-presigned-domain-url \
  --domain-id d-d4ujiazahn5b \
  --user-profile-name default-user \
  --region us-east-1 \
  --query 'AuthorizedUrl' \
  --output text

# Copy the URL and paste into browser
```

The URL will look like:
```
https://d-d4ujiazahn5b.studio.us-east-1.sagemaker.aws/jupyter/default/lab?authToken=...
```

### Method 3: Python Script (For Developers)

```python
import boto3
import webbrowser

# Create SageMaker client
sagemaker = boto3.client('sagemaker', region_name='us-east-1')

# Generate presigned URL
response = sagemaker.create_presigned_domain_url(
    DomainId='d-d4ujiazahn5b',
    UserProfileName='default-user',
    SessionExpirationDurationInSeconds=3600  # 1 hour
)

# Open in browser
url = response['AuthorizedUrl']
print(f"Opening SageMaker Studio: {url}")
webbrowser.open(url)
```

## Why Can't I Use analysis.savantpraxis.com?

### The Short Answer
**SageMaker Studio is not a traditional web application.** You cannot put it behind an ALB with a custom domain.

### The Technical Reason

SageMaker Studio requires:
1. **Dynamic presigned URLs** that change per session
2. **AWS authentication tokens** embedded in the URL
3. **WebSocket connections** for real-time features
4. **Session management** by AWS infrastructure

An ALB + custom domain setup cannot handle these requirements.

## What is analysis.savantpraxis.com For?

The custom domain and ALB infrastructure in your Terraform code was likely set up with a misunderstanding of how SageMaker works.

### What It CANNOT Do
- ❌ Proxy SageMaker Studio
- ❌ Provide a custom URL for Studio access
- ❌ Replace the need for presigned URLs

### What It COULD Do (If Reconfigured)

**Option 1: SageMaker Model Endpoints**
- Deploy trained ML models
- Real-time inference API
- Custom domain for predictions

**Option 2: Web Portal**
- Custom web app that generates presigned URLs
- User-friendly interface
- Authentication layer

**Option 3: Data Science Platform**
- JupyterHub or similar
- Custom notebook environment
- Alternative to SageMaker Studio

## Current Infrastructure Issues

### What's Deployed
```
analysis.savantpraxis.com
    ↓
  Route 53 (DNS)
    ↓
  Application Load Balancer (ALB)
    ↓
  Target Group (IP-based)
    ↓
  ??? (NOTHING REGISTERED) ← This is the problem
```

### Why 503 Error
- The ALB target group has **zero registered targets**
- Health checks have **no targets to check**
- ALB returns **503 Service Unavailable**

This is expected because:
1. No `aws_lb_target_group_attachment` in Terraform
2. SageMaker Studio IPs are not static
3. SageMaker Studio is not designed to be a target

## Fixing Your Setup

### Option 1: Use SageMaker Properly (Recommended)

**Keep it simple:**
1. Access SageMaker via AWS Console or CLI
2. Remove the custom domain infrastructure (not needed)
3. Update your terraform.tfvars:
   ```hcl
   enable_custom_domain = false
   ```
4. Run `terraform apply`

### Option 2: Build a Web Portal

**If you want analysis.savantpraxis.com to work:**

1. Deploy a web application behind the ALB
2. Application generates presigned URLs
3. Redirects users to SageMaker Studio

**Architecture:**
```
User → analysis.savantpraxis.com
       ↓
     ALB
       ↓
     Web App (Flask/Node.js/etc)
       ├── Authentication
       ├── AWS SDK
       └── Generate presigned URL
       ↓
     Redirect to SageMaker
```

**Example Flask App:**
```python
from flask import Flask, redirect
import boto3

app = Flask(__name__)
sagemaker = boto3.client('sagemaker', region_name='us-east-1')

@app.route('/')
def index():
    response = sagemaker.create_presigned_domain_url(
        DomainId='d-d4ujiazahn5b',
        UserProfileName='default-user'
    )
    return redirect(response['AuthorizedUrl'])
```

### Option 3: Use for Model Endpoints

**Deploy ML models:**
```bash
# Deploy a model endpoint
aws sagemaker create-endpoint --endpoint-name my-model

# Configure ALB to point to endpoint
# Update target group to use endpoint URL
```

## Immediate Action Steps

### Step 1: Access SageMaker Now

Run this command:
```bash
aws sagemaker create-presigned-domain-url \
  --domain-id d-d4ujiazahn5b \
  --user-profile-name default-user \
  --region us-east-1 \
  --query 'AuthorizedUrl' \
  --output text
```

Copy the URL and open in browser.

### Step 2: Decide on Custom Domain

Ask yourself:
- Do I need `analysis.savantpraxis.com` at all?
- If yes, what should it do?
- Can I just use AWS Console for SageMaker?

### Step 3: Update Infrastructure

Based on your decision:

**If removing custom domain:**
```bash
# Edit terraform.tfvars
echo 'enable_custom_domain = false' >> terraform.tfvars

# Apply changes
terraform apply
```

**If keeping custom domain:**
- Deploy a web application
- Configure target group
- Register targets

## Frequently Asked Questions

### Q: Why does the SageMaker URL expire?
**A:** SageMaker URLs contain time-limited authentication tokens for security. This is by design.

### Q: Can I bookmark the SageMaker URL?
**A:** No, bookmarks won't work because the URL changes each time. Bookmark the AWS Console page instead.

### Q: Can I use a custom domain for SageMaker?
**A:** Not for Studio directly. You can build a portal that redirects to SageMaker.

### Q: What about SSO/Okta integration?
**A:** SSO controls who can access SageMaker, but doesn't change how you access it. You still need presigned URLs.

### Q: Is there a way to avoid the AWS Console?
**A:** Yes, use AWS CLI or SDK to generate URLs programmatically.

### Q: What if I'm in SSO mode?
**A:** Same process - use Console or CLI. The presigned URL generation works with SSO authentication.

## User Profile Names

To find your user profile name:

```bash
# List all user profiles
aws sagemaker list-user-profiles \
  --domain-id d-d4ujiazahn5b \
  --region us-east-1 \
  --query 'UserProfiles[*].UserProfileName'
```

Use one of these names in the `create-presigned-domain-url` command.

## Troubleshooting

### Error: "User profile not found"
- List user profiles (command above)
- Use exact name from the list
- Check if you have permission to access that profile

### Error: "Access denied"
- Check your IAM permissions
- Ensure you have `sagemaker:CreatePresignedDomainUrl` permission
- See IAM_PERMISSIONS.md for required policies

### Still getting 503 on custom domain
- This is expected if no backend is configured
- Either remove the custom domain or deploy a web app
- See TROUBLESHOOTING_SAGEMAKER_ACCESS.md for details

## Summary

✅ **To Access SageMaker Studio:**
- Use AWS Console (easiest)
- Or generate presigned URL via CLI/SDK
- URLs expire and need to be regenerated

❌ **Cannot Use Custom Domain for Studio:**
- SageMaker Studio doesn't work behind ALB
- The 503 error is expected with current setup
- Would need a web portal application to make it work

📝 **Recommended Action:**
- Access SageMaker via AWS Console
- Remove unused custom domain infrastructure
- Or repurpose it for deployed models/endpoints

## Need More Help?

See these documents in the repository:
- **TROUBLESHOOTING_SAGEMAKER_ACCESS.md** - Detailed explanation
- **SETUP.md** - Infrastructure setup guide  
- **README.md** - General documentation
- **IAM_PERMISSIONS.md** - Required permissions
