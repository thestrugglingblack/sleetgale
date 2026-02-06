# Quick Fix: Route 53 Access Denied Error

## The Error You're Seeing

```
Error: listing Route 53 Hosted Zone (Z05687192QVMDJJL9QM6A) tags: 
operation error Route 53: ListTagsForResource, 
https response error StatusCode: 403, RequestID: bb4f19a4-ab6f-4ebc-a34c-63c0ad53fb95, 
api error AccessDenied: User: arn:aws:iam::378737770782:user/thestrugglingblack 
is not authorized to perform: route53:ListTagsForResource on resource: 
arn:aws:route53:::hostedzone/Z05687192QVMDJJL9QM6A 
because no identity-based policy allows the route53:ListTagsForResource action
```

## Root Cause

Your IAM user `thestrugglingblack` lacks the `route53:ListTagsForResource` permission required by Terraform to read Route 53 hosted zone information.

## Solution: Add Route 53 Permissions

### Option 1: AWS CLI (Fastest)

Run this command to add the necessary permissions:

```bash
aws iam put-user-policy \
  --user-name thestrugglingblack \
  --policy-name Route53ReadAccess \
  --policy-document file://policies/route53-read-policy.json
```

**Or if you prefer inline JSON:**

```bash
aws iam put-user-policy \
  --user-name thestrugglingblack \
  --policy-name Route53ReadAccess \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "route53:GetHostedZone",
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:GetChange",
        "route53:ListTagsForResource"
      ],
      "Resource": "*"
    }]
  }'
```

### Option 2: AWS Console

1. Go to **AWS Console** → **IAM** → **Users**
2. Click on **thestrugglingblack**
3. Click **Add permissions** → **Create inline policy**
4. Click **JSON** tab
5. Paste this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Route53ReadAccess",
      "Effect": "Allow",
      "Action": [
        "route53:GetHostedZone",
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:GetChange",
        "route53:ListTagsForResource"
      ],
      "Resource": "*"
    }
  ]
}
```

6. Click **Review policy**
7. Name it: `Route53ReadAccess`
8. Click **Create policy**

### Option 3: Apply via IAM Group (Recommended for Teams)

If you're using IAM groups:

```bash
aws iam put-group-policy \
  --group-name YOUR_GROUP_NAME \
  --policy-name Route53ReadAccess \
  --policy-document file://policies/route53-read-policy.json
```

## Verify the Fix

After applying the policy:

```bash
# 1. Verify the policy was attached
aws iam list-user-policies --user-name thestrugglingblack

# 2. View the policy details
aws iam get-user-policy \
  --user-name thestrugglingblack \
  --policy-name Route53ReadAccess

# 3. Wait 5-10 seconds for IAM to propagate

# 4. Retry your Terraform command
terraform plan
```

## If You Need More Permissions

This is the minimum fix for your current error. If you encounter additional permission errors, you have two options:

### Quick: Add Complete Sleetgale Policy

```bash
aws iam put-user-policy \
  --user-name thestrugglingblack \
  --policy-name SleetgaleTerraformPolicy \
  --policy-document file://policies/sleetgale-complete-policy.json
```

### Detailed: See Full Documentation

- **[IAM_PERMISSIONS.md](IAM_PERMISSIONS.md)** - Complete permission breakdown by feature
- **[policies/README.md](policies/README.md)** - Usage instructions for all policy files

## Troubleshooting

**Policy not working?**
- Wait 10-30 seconds for IAM changes to propagate
- Verify you're using the correct AWS credentials: `aws sts get-caller-identity`
- Check the policy was attached: `aws iam list-user-policies --user-name thestrugglingblack`

**Still getting errors?**
- Check for deny policies or SCPs that might override this
- Ensure no permission boundaries are restricting access
- See [SETUP.md](SETUP.md) troubleshooting section

**Need different permissions?**
- Each AWS service error will tell you the exact action needed
- Add that action to your policy and reapply
- See [IAM_PERMISSIONS.md](IAM_PERMISSIONS.md) for service-specific permissions

## Next Steps

1. ✅ Apply the Route 53 policy above
2. ✅ Wait 10 seconds
3. ✅ Run `terraform plan` again
4. 📝 If you get more permission errors, apply the complete policy
5. 📚 Review [IAM_PERMISSIONS.md](IAM_PERMISSIONS.md) to understand all required permissions

## Related Files

- **policies/route53-read-policy.json** - The policy file for this fix
- **policies/sleetgale-complete-policy.json** - All permissions for full deployment
- **IAM_PERMISSIONS.md** - Detailed permission documentation
- **SETUP.md** - Complete setup guide with troubleshooting
