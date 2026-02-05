terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  profile = var.profile_name

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "sleetgale"
      ManagedBy   = "Terraform"
    }
  }
}
