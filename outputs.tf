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
  description = "The ARN of the default SageMaker user profile (IAM mode only)"
  value       = var.enable_sso ? null : aws_sagemaker_user_profile.default_user[0].arn
}

output "sagemaker_execution_role_arn" {
  description = "The ARN of the SageMaker execution role"
  value       = local.sagemaker_execution_role_arn
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

output "custom_domain_url" {
  description = "The custom domain URL for SageMaker Studio (if enabled)"
  value       = var.enable_custom_domain ? "https://${var.custom_domain_name}" : null
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer (if custom domain is enabled)"
  value       = var.enable_custom_domain ? aws_lb.sagemaker_alb[0].dns_name : null
}

output "certificate_arn" {
  description = "The ARN of the ACM certificate"
  value       = var.enable_custom_domain ? local.certificate_arn : null
}

output "route53_zone_nameservers" {
  description = "The name servers for the Route 53 zone (if created)"
  value       = var.enable_custom_domain && var.create_route53_zone ? aws_route53_zone.custom_domain[0].name_servers : null
}

output "sso_permission_set_arns" {
  description = "ARNs of SSO permission sets (if SSO is enabled)"
  value = var.enable_sso ? {
    admin = aws_ssoadmin_permission_set.sagemaker_admin[0].arn
    user  = aws_ssoadmin_permission_set.sagemaker_user[0].arn
  } : null
}

output "auth_mode" {
  description = "The authentication mode of the SageMaker domain"
  value       = var.enable_sso ? "SSO" : "IAM"
}
