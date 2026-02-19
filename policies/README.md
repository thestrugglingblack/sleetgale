# IAM Policy Files

This directory contains ready-to-use IAM policy JSON files for deploying Sleetgale infrastructure with Terraform.

## Available Policies

### 1. route53-read-policy.json

**Purpose**: Quick fix for Route 53 access denied errors, specifically the `route53:ListTagsForResource` error.

**Use when**: You encounter this error:
```
Error: User is not authorized to perform: route53:ListTagsForResource
```

**Apply with AWS CLI**:
```bash
aws iam put-user-policy \
  --user-name YOUR_USERNAME \
  --policy-name Route53ReadAccess \
  --policy-document file://policies/route53-read-policy.json
```

**Or for a group**:
```bash
aws iam put-group-policy \
  --group-name YOUR_GROUP \
  --policy-name Route53ReadAccess \
  --policy-document file://policies/route53-read-policy.json
```

### 2. sleetgale-complete-policy.json

**Purpose**: Complete policy with all permissions needed for full Sleetgale deployment (basic + custom domain + SSO).

**Use when**: Setting up a new deployment or need all features.

**Apply with AWS CLI**:
```bash
aws iam put-user-policy \
  --user-name YOUR_USERNAME \
  --policy-name SleetgaleTerraformPolicy \
  --policy-document file://policies/sleetgale-complete-policy.json
```

**Or for a group**:
```bash
aws iam put-group-policy \
  --group-name YOUR_GROUP \
  --policy-name SleetgaleTerraformPolicy \
  --policy-document file://policies/sleetgale-complete-policy.json
```

## How to Use

### Option 1: AWS Console

1. Go to **IAM** → **Users** (or **User groups**)
2. Select your user/group
3. Click **Add permissions** → **Create inline policy**
4. Click **JSON** tab
5. Copy the contents of the desired policy file
6. Paste into the editor
7. Click **Review policy**
8. Name it (e.g., `SleetgaleTerraformPolicy`)
9. Click **Create policy**

### Option 2: AWS CLI (Recommended)

```bash
# Navigate to the sleetgale directory
cd /path/to/sleetgale

# For user:
aws iam put-user-policy \
  --user-name YOUR_USERNAME \
  --policy-name PolicyName \
  --policy-document file://policies/POLICY_FILE.json

# For group:
aws iam put-group-policy \
  --group-name YOUR_GROUP \
  --policy-name PolicyName \
  --policy-document file://policies/POLICY_FILE.json
```

### Option 3: Terraform (Advanced)

You can also manage these policies with Terraform itself:

```hcl
resource "aws_iam_user_policy" "sleetgale_deploy" {
  name   = "SleetgaleTerraformPolicy"
  user   = "your-username"
  policy = file("${path.module}/policies/sleetgale-complete-policy.json")
}
```

## Verification

After applying a policy, verify it was attached:

```bash
# For user policies:
aws iam list-user-policies --user-name YOUR_USERNAME
aws iam get-user-policy --user-name YOUR_USERNAME --policy-name PolicyName

# For group policies:
aws iam list-group-policies --group-name YOUR_GROUP
aws iam get-group-policy --group-name YOUR_GROUP --policy-name PolicyName

# Check current identity:
aws sts get-caller-identity
```

## Troubleshooting

**Policy not taking effect immediately**:
- IAM changes can take a few seconds to propagate
- Try waiting 10-30 seconds and retry your Terraform command

**Still getting permission errors**:
- Verify the policy is attached: `aws iam list-user-policies --user-name YOUR_USERNAME`
- Check if you're using the correct AWS credentials: `aws sts get-caller-identity`
- Look for any deny policies that might override these permissions
- Check service control policies (SCPs) if you're in an AWS Organization

**Need more specific permissions**:
- See [IAM_PERMISSIONS.md](../IAM_PERMISSIONS.md) for detailed breakdown
- Copy the specific statement you need from that document
- Add it to your policy

## Security Best Practices

1. **Use Groups**: Assign policies to groups, not individual users
2. **Least Privilege**: Start with route53-read-policy.json, add more as needed
3. **Regular Audits**: Review and remove unused permissions periodically
4. **Separate Environments**: Use different credentials for dev/staging/prod
5. **Document Changes**: Keep track of what permissions you've added and why

## See Also

- [IAM_PERMISSIONS.md](../IAM_PERMISSIONS.md) - Detailed permission documentation
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
