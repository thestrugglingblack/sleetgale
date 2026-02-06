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
  description = "Route 53 hosted zone ID for DNS records. If not provided and create_route53_zone is true, a new zone will be created"
  type        = string
  default     = ""
}

variable "create_route53_zone" {
  description = "Create a new Route 53 hosted zone for the custom domain"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of existing ACM certificate. If not provided and enable_custom_domain is true, a new certificate will be created"
  type        = string
  default     = ""
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

# Okta OIDC Configuration (Alternative to SAML)
variable "enable_okta_auth" {
  description = "Enable Okta OIDC authentication via ALB (alternative to SSO SAML)"
  type        = bool
  default     = false
}

variable "okta_issuer_url" {
  description = "Okta issuer URL (e.g., https://dev-12345678.okta.com/oauth2/default)"
  type        = string
  default     = ""
}

variable "okta_client_id" {
  description = "Okta OIDC application client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "okta_client_secret" {
  description = "Okta OIDC application client secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "okta_authorization_endpoint" {
  description = "Okta authorization endpoint (e.g., https://dev-12345678.okta.com/oauth2/default/v1/authorize)"
  type        = string
  default     = ""
}

variable "okta_token_endpoint" {
  description = "Okta token endpoint (e.g., https://dev-12345678.okta.com/oauth2/default/v1/token)"
  type        = string
  default     = ""
}

variable "okta_user_info_endpoint" {
  description = "Okta user info endpoint (e.g., https://dev-12345678.okta.com/oauth2/default/v1/userinfo)"
  type        = string
  default     = ""
}

variable "okta_session_timeout" {
  description = "Okta authentication session timeout in seconds (default: 604800 = 7 days)"
  type        = number
  default     = 604800
}
