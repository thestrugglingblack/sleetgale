output "sagemaker_domain_id" {
  description = "The ID of the SageMaker Studio domain"
  value       = aws_sagemaker_domain.sleetgale.id
}

output "sagemaker_domain_arn" {
  description = "The ARN of the SageMaker Studio domain"
  value       = aws_sagemaker_domain.sleetgale.arn
}

output "sagemaker_domain_url" {
  description = "The URL to access SageMaker Studio"
  value       = aws_sagemaker_domain.sleetgale.url
}

output "sagemaker_user_profile_arn" {
  description = "The ARN of the default SageMaker user profile"
  value       = aws_sagemaker_user_profile.default_user.arn
}

output "sagemaker_execution_role_arn" {
  description = "The ARN of the SageMaker execution role"
  value       = aws_iam_role.sagemaker_execution_role.arn
}

output "sagemaker_bucket_name" {
  description = "The name of the S3 bucket for SageMaker artifacts"
  value       = aws_s3_bucket.sagemaker_bucket.id
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.sagemaker_vpc.id
}

output "subnet_ids" {
  description = "The IDs of the subnets"
  value       = aws_subnet.sagemaker_subnets[*].id
}
