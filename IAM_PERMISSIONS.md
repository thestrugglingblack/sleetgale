# IAM Permissions Required for Sleetgale Deployment

This document outlines the AWS IAM permissions required to deploy and manage the Sleetgale infrastructure using Terraform.

## Overview

The user or role executing Terraform needs permissions to create, read, update, and delete various AWS resources. The specific permissions required depend on which features you're deploying.

## Minimum Required Permissions

### Basic Deployment (SageMaker, VPC, S3)

The following permissions are required for the basic SageMaker deployment:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SageMakerPermissions",
      "Effect": "Allow",
      "Action": [
        "sagemaker:CreateDomain",
        "sagemaker:DeleteDomain",
        "sagemaker:DescribeDomain",
        "sagemaker:UpdateDomain",
        "sagemaker:CreateUserProfile",
        "sagemaker:DeleteUserProfile",
        "sagemaker:DescribeUserProfile",
        "sagemaker:UpdateUserProfile",
        "sagemaker:ListTags",
        "sagemaker:AddTags",
        "sagemaker:DeleteTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "VPCPermissions",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:DescribeVpcs",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:DescribeSubnets",
        "ec2:CreateInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:DescribeInternetGateways",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:DescribeRouteTables",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:DescribeSecurityGroups",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeTags",
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3Permissions",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging",
        "s3:GetBucketLogging",
        "s3:PutBucketLogging",
        "s3:GetBucketAcl",
        "s3:PutBucketAcl",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPermissions",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:PassRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:ListRoleTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CallerIdentity",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

## Additional Permissions for Custom Domain with SSL

**Required for the error you're experiencing:**

When using custom domain features (`enable_custom_domain = true`), you need additional Route 53 and ACM permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Route53ReadPermissions",
      "Effect": "Allow",
      "Action": [
        "route53:GetHostedZone",
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:GetChange",
        "route53:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Route53WritePermissions",
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:CreateHostedZone",
        "route53:DeleteHostedZone",
        "route53:ChangeTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ACMPermissions",
      "Effect": "Allow",
      "Action": [
        "acm:RequestCertificate",
        "acm:DescribeCertificate",
        "acm:DeleteCertificate",
        "acm:ListCertificates",
        "acm:AddTagsToCertificate",
        "acm:ListTagsForCertificate",
        "acm:RemoveTagsFromCertificate"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ALBPermissions",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags",
        "elasticloadbalancing:DescribeTags"
      ],
      "Resource": "*"
    }
  ]
}
```

### Key Permission for Your Error

The specific error you're encountering is:
```
User is not authorized to perform: route53:ListTagsForResource on resource: arn:aws:route53:::hostedzone/Z05687192QVMDJJL9QM6A
```

This requires the `route53:ListTagsForResource` permission, which is included in the Route 53 policy above.

## Additional Permissions for SSO/Okta Integration

When using SSO features (`enable_sso = true`), you need AWS SSO permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SSOAdminPermissions",
      "Effect": "Allow",
      "Action": [
        "sso:DescribeRegisteredRegions",
        "sso:ListInstances"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SSOPermissionSetPermissions",
      "Effect": "Allow",
      "Action": [
        "sso-admin:CreatePermissionSet",
        "sso-admin:DeletePermissionSet",
        "sso-admin:DescribePermissionSet",
        "sso-admin:UpdatePermissionSet",
        "sso-admin:AttachManagedPolicyToPermissionSet",
        "sso-admin:DetachManagedPolicyFromPermissionSet",
        "sso-admin:ListManagedPoliciesInPermissionSet",
        "sso-admin:PutInlinePolicyToPermissionSet",
        "sso-admin:GetInlinePolicyForPermissionSet",
        "sso-admin:DeleteInlinePolicyFromPermissionSet",
        "sso-admin:ProvisionPermissionSet",
        "sso-admin:DescribePermissionSetProvisioningStatus",
        "sso-admin:ListPermissionSets",
        "sso-admin:ListInstances",
        "sso-admin:TagResource",
        "sso-admin:UntagResource",
        "sso-admin:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IdentityStorePermissions",
      "Effect": "Allow",
      "Action": [
        "identitystore:DescribeUser",
        "identitystore:DescribeGroup",
        "identitystore:ListUsers",
        "identitystore:ListGroups"
      ],
      "Resource": "*"
    }
  ]
}
```

## Complete Combined Policy

For a complete deployment with all features (Basic + Custom Domain + SSO), you can use this combined policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SleetgaleFullAccess",
      "Effect": "Allow",
      "Action": [
        "sagemaker:*",
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:DescribeVpcs",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:DescribeSubnets",
        "ec2:CreateInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:DescribeInternetGateways",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:DescribeRouteTables",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:DescribeSecurityGroups",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeTags",
        "ec2:DescribeAvailabilityZones",
        "s3:*",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:PassRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:ListRoleTags",
        "sts:GetCallerIdentity",
        "route53:GetHostedZone",
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:ChangeResourceRecordSets",
        "route53:GetChange",
        "route53:ListTagsForResource",
        "route53:ChangeTagsForResource",
        "route53:CreateHostedZone",
        "route53:DeleteHostedZone",
        "acm:RequestCertificate",
        "acm:DescribeCertificate",
        "acm:DeleteCertificate",
        "acm:ListCertificates",
        "acm:AddTagsToCertificate",
        "acm:ListTagsForCertificate",
        "acm:RemoveTagsFromCertificate",
        "elasticloadbalancing:*",
        "sso:DescribeRegisteredRegions",
        "sso:ListInstances",
        "sso-admin:*",
        "identitystore:DescribeUser",
        "identitystore:DescribeGroup",
        "identitystore:ListUsers",
        "identitystore:ListGroups"
      ],
      "Resource": "*"
    }
  ]
}
```

## How to Apply These Permissions

### Option 1: Update IAM User Policy

1. **AWS Console → IAM → Users**
2. Select your user (e.g., `thestrugglingblack`)
3. Click **"Add permissions"** → **"Add inline policy"**
4. Select **"JSON"** tab
5. Paste the appropriate policy from above
6. Name it something like `SleetgaleTerraformPolicy`
7. Click **"Create policy"**

### Option 2: Update IAM Group Policy

If you're using IAM groups (recommended):

1. **AWS Console → IAM → User groups**
2. Select your group (or create a new one like `TerraformAdmins`)
3. Click **"Permissions"** tab → **"Add permissions"** → **"Create inline policy"**
4. Select **"JSON"** tab
5. Paste the appropriate policy from above
6. Name it something like `SleetgaleTerraformPolicy`
7. Click **"Create policy"**
8. Add your user to the group if not already a member

### Option 3: AWS CLI

To add the policy via AWS CLI:

```bash
# Create a file named sleetgale-policy.json with the policy content

# For inline user policy:
aws iam put-user-policy \
  --user-name thestrugglingblack \
  --policy-name SleetgaleTerraformPolicy \
  --policy-document file://sleetgale-policy.json

# For inline group policy:
aws iam put-group-policy \
  --group-name TerraformAdmins \
  --policy-name SleetgaleTerraformPolicy \
  --policy-document file://sleetgale-policy.json
```

## Quick Fix for Your Current Error

To quickly resolve your specific Route 53 error, create a file named `route53-fix-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Route53TagsAccess",
      "Effect": "Allow",
      "Action": [
        "route53:ListTagsForResource",
        "route53:GetHostedZone",
        "route53:ListHostedZones"
      ],
      "Resource": "*"
    }
  ]
}
```

Then apply it:

```bash
aws iam put-user-policy \
  --user-name thestrugglingblack \
  --policy-name Route53TagsAccess \
  --policy-document file://route53-fix-policy.json
```

## Security Best Practices

1. **Use Groups**: Assign policies to groups rather than individual users
2. **Principle of Least Privilege**: Start with the minimum required permissions and add more as needed
3. **Separate Environments**: Use different IAM users/roles for dev, staging, and production
4. **Regular Audits**: Periodically review and remove unnecessary permissions
5. **Use IAM Roles**: For production, consider using IAM roles with assume role policies instead of user credentials

## Troubleshooting

### Still Getting Permission Errors?

1. **Check Policy Attachment**: Ensure the policy is attached to your user or group
   ```bash
   aws iam list-user-policies --user-name thestrugglingblack
   aws iam list-attached-user-policies --user-name thestrugglingblack
   ```

2. **Verify Credentials**: Make sure you're using the correct AWS credentials
   ```bash
   aws sts get-caller-identity
   ```

3. **Check for Deny Policies**: Ensure no service control policies (SCPs) or permission boundaries are blocking access

4. **Wait for Propagation**: IAM changes can take a few seconds to propagate

### Need More Specific Permissions?

If you encounter other permission errors:

1. Note the exact action from the error message (e.g., `route53:ListTagsForResource`)
2. Add that action to your policy under the appropriate service
3. Reapply the policy

## References

- [AWS IAM Policy Reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies.html)
- [SageMaker Actions](https://docs.aws.amazon.com/sagemaker/latest/APIReference/API_Operations.html)
- [Route 53 Actions](https://docs.aws.amazon.com/Route53/latest/APIReference/API_Operations.html)
- [ACM Actions](https://docs.aws.amazon.com/acm/latest/APIReference/API_Operations.html)
