# IAM role for SageMaker Studio domain execution
resource "aws_iam_role" "sagemaker_execution_role" {
  name = "${var.domain_name}-sagemaker-execution-role"

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
    ]
  })

  tags = {
    Name = "${var.domain_name}-execution-role"
  }
}

# Attach the AWS managed SageMaker execution policy
resource "aws_iam_role_policy_attachment" "sagemaker_execution_policy" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Additional policy for S3 access (minimal for cost efficiency)
resource "aws_iam_role_policy" "sagemaker_s3_policy" {
  name = "${var.domain_name}-s3-policy"
  role = aws_iam_role.sagemaker_execution_role.id

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

# S3 Bucket for SageMaker artifacts (using standard storage class for cost efficiency)
resource "aws_s3_bucket" "sagemaker_bucket" {
  bucket = "${var.domain_name}-sagemaker-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.domain_name}-sagemaker-bucket"
  }
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "sagemaker_bucket_pab" {
  bucket = aws_s3_bucket.sagemaker_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
