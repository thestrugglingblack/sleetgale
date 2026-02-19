variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "profile_name" {
  description = "AWS CLI profile name"
  type        = string
  default     = "default"
}

variable "domain_name" {
  description = "SageMaker Studio domain name"
  type        = string
  default     = "sleetgale"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "CIDR blocks for subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# Custom Domain and SSL Configuration
variable "enable_custom_domain" {
  description = "Enable custom domain configuration with SSL"
  type        = bool
  default     = false
}

variable "custom_domain_name" {
  description = "Custom domain name for SageMaker Studio (e.g., sagemaker.savantpraxis.com)"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = <<-EOT
    Route 53 hosted zone ID for DNS records (RECOMMENDED: use existing zone).
    
    To use an EXISTING zone (recommended):
    - Set this to your zone ID (e.g., "Z1234567890ABC")
    - Set create_route53_zone = false
    - Terraform will ONLY create an A record for custom_domain_name
    
    To create a NEW zone (not recommended):
    - Leave this empty
    - Set create_route53_zone = true
    - Terraform will create and manage the entire zone
    
    Find your zone ID: aws route53 list-hosted-zones
  EOT
  type        = string
  default     = ""
}

variable "create_route53_zone" {
  description = <<-EOT
    Create a new Route 53 hosted zone (default: false).
    
    RECOMMENDED: Keep this false and use route53_zone_id instead.
    
    Only set to true if:
    - You don't have an existing Route53 zone
    - You want Terraform to manage the entire DNS zone
    - You understand you'll need to update domain registrar nameservers
  EOT
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = <<-EOT
    ARN of existing ACM certificate (RECOMMENDED: use existing certificate).
    
    To use an EXISTING certificate (recommended):
    - Provide the full ARN of your certificate
    - Certificate MUST be in us-east-1 region for ALB
    - Terraform will NOT create a new certificate
    - Terraform will NOT add validation records to your DNS
    
    To create a NEW certificate:
    - Leave this empty
    - Terraform will create a new certificate
    - Terraform will add DNS validation records to your Route53 zone
    - Certificate validation can take 5-10 minutes
    
    Find your certificate ARN: aws acm list-certificates --region us-east-1
  EOT
  type        = string
  default     = ""
  sensitive   = false
}

# Okta SSO Configuration
variable "enable_sso" {
  description = "Enable AWS SSO (IAM Identity Center) with Okta integration"
  type        = bool
  default     = false
}

variable "sso_instance_arn" {
  description = "ARN of the AWS SSO instance. Required if enable_sso is true. Can be found in IAM Identity Center console"
  type        = string
  default     = ""
}

variable "sso_identity_store_id" {
  description = "ID of the AWS SSO identity store. Required if enable_sso is true. Can be found in IAM Identity Center console"
  type        = string
  default     = ""
}

variable "okta_idp_metadata_url" {
  description = "Okta SAML 2.0 IdP metadata URL for SSO integration"
  type        = string
  default     = ""
}

variable "sso_admin_group_name" {
  description = "Name of the Okta/SSO group for SageMaker administrators"
  type        = string
  default     = "SageMakerAdmins"
}

variable "sso_user_group_name" {
  description = "Name of the Okta/SSO group for SageMaker users"
  type        = string
  default     = "SageMakerUsers"
}

# Auth0 Authentication Configuration (Alternative to SAML)
variable "enable_auth0" {
  description = "Enable Auth0 authentication via ALB (alternative to SSO SAML)"
  type        = bool
  default     = false
}

variable "auth0_domain" {
  description = "Auth0 domain (e.g., dev-12345678.us.auth0.com)"
  type        = string
  default     = ""
}

variable "auth0_client_id" {
  description = "Auth0 application client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "auth0_client_secret" {
  description = "Auth0 application client secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "auth0_session_timeout" {
  description = "Auth0 authentication session timeout in seconds (default: 604800 = 7 days)"
  type        = number
  default     = 604800
}
