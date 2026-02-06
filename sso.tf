# AWS IAM Identity Center (SSO) and Okta Integration

# Note: AWS IAM Identity Center must be manually enabled in the AWS account before using these resources
# The sso_instance_arn and sso_identity_store_id must be provided as variables

# Note: This file uses data.aws_caller_identity.current which is defined in iam.tf

# Validation for SSO configuration
locals {
  validate_sso_config = var.enable_sso && (var.sso_instance_arn == "" || var.sso_identity_store_id == "") ? tobool("ERROR: When enable_sso is true, both sso_instance_arn and sso_identity_store_id must be provided. Run: aws sso-admin list-instances") : true
}

# Permission Set for SageMaker Administrators
resource "aws_ssoadmin_permission_set" "sagemaker_admin" {
  count            = var.enable_sso ? 1 : 0
  name             = "${var.domain_name}-sagemaker-admin"
  description      = "Permission set for SageMaker administrators"
  instance_arn     = var.sso_instance_arn
  session_duration = "PT8H" # 8 hours
}

# Attach AWS managed policy for SageMaker full access to admin permission set
resource "aws_ssoadmin_managed_policy_attachment" "sagemaker_admin_policy" {
  count              = var.enable_sso ? 1 : 0
  instance_arn       = var.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
  permission_set_arn = aws_ssoadmin_permission_set.sagemaker_admin[0].arn
}

# Permission Set for SageMaker Users
resource "aws_ssoadmin_permission_set" "sagemaker_user" {
  count            = var.enable_sso ? 1 : 0
  name             = "${var.domain_name}-sagemaker-user"
  description      = "Permission set for SageMaker users"
  instance_arn     = var.sso_instance_arn
  session_duration = "PT8H" # 8 hours
}

# Inline policy for SageMaker user permission set
resource "aws_ssoadmin_permission_set_inline_policy" "sagemaker_user_policy" {
  count = var.enable_sso ? 1 : 0
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:DescribeDomain",
          "sagemaker:DescribeUserProfile",
          "sagemaker:CreatePresignedDomainUrl",
          "sagemaker:ListTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateApp",
          "sagemaker:DeleteApp",
          "sagemaker:DescribeApp",
          "sagemaker:ListApps"
        ]
        Resource = "arn:aws:sagemaker:${var.aws_region}:${data.aws_caller_identity.current.account_id}:app/*"
      }
    ]
  })
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.sagemaker_user[0].arn
}

# IAM role for SSO users to assume
resource "aws_iam_role" "sso_sagemaker_execution_role" {
  count = var.enable_sso ? 1 : 0
  name  = "${var.domain_name}-sso-sagemaker-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
      # NOTE: The SAML provider trust relationship is commented out as it requires
      # manual creation of the SAML provider in IAM. When using AWS IAM Identity Center,
      # the SAML provider is managed by the service and not needed here.
      # If using standalone Okta SAML (without IAM Identity Center), uncomment this:
      # {
      #   Effect = "Allow"
      #   Principal = {
      #     Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:saml-provider/OktaSAML"
      #   }
      #   Action = "sts:AssumeRoleWithSAML"
      #   Condition = {
      #     StringEquals = {
      #       "SAML:aud" = "https://signin.aws.amazon.com/saml"
      #     }
      #   }
      # }
    ]
  })

  tags = {
    Name = "${var.domain_name}-sso-execution-role"
  }
}

# Attach the AWS managed SageMaker execution policy to SSO role
resource "aws_iam_role_policy_attachment" "sso_sagemaker_execution_policy" {
  count      = var.enable_sso ? 1 : 0
  role       = aws_iam_role.sso_sagemaker_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# S3 policy for SSO execution role
resource "aws_iam_role_policy" "sso_sagemaker_s3_policy" {
  count = var.enable_sso ? 1 : 0
  name  = "${var.domain_name}-sso-s3-policy"
  role  = aws_iam_role.sso_sagemaker_execution_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.sagemaker_bucket.arn}",
          "${aws_s3_bucket.sagemaker_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Local variable to determine which execution role to use
locals {
  sagemaker_execution_role_arn = var.enable_sso ? aws_iam_role.sso_sagemaker_execution_role[0].arn : aws_iam_role.sagemaker_execution_role.arn
}
