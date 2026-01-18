# sleetgale

Terraform configuration for creating the cheapest Amazon SageMaker Studio instance.

## Overview

This Terraform configuration creates a cost-optimized Amazon SageMaker Studio environment with:
- A SageMaker Studio domain named "sleetgale"
- IAM-based authentication (no SSO costs)
- VPC with 2 subnets across different availability zones
- Minimal instance types (ml.t3.medium for compute, "system" for JupyterServer)
- S3 bucket for SageMaker artifacts
- Security groups and IAM roles with least-privilege access

## Cost Optimization Features

- **Instance Types**: Uses `ml.t3.medium` (cheapest compute instance) and `system` (no-cost JupyterServer)
- **Authentication**: IAM mode instead of AWS SSO (no additional SSO costs)
- **Storage**: Standard S3 storage class
- **Networking**: Simple VPC setup with minimal resources

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with permissions to create SageMaker, VPC, IAM, and S3 resources

## Usage

### Initialize Terraform

```bash
terraform init
```

### Preview Changes

```bash
terraform plan
```

### Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm the deployment.

### Access SageMaker Studio

After deployment, you can access SageMaker Studio:

1. Go to the AWS Console
2. Navigate to Amazon SageMaker > Domains
3. Select the "sleetgale" domain
4. Click on the user profile "default-user"
5. Click "Launch" > "Studio"

Alternatively, use the domain URL from the Terraform outputs:

```bash
terraform output sagemaker_domain_url
```

### Destroy Infrastructure

When you're done, destroy all resources to avoid ongoing costs:

```bash
terraform destroy
```

Type `yes` when prompted to confirm the destruction.

## Configuration Variables

You can customize the deployment by creating a `terraform.tfvars` file:

```hcl
aws_region   = "us-east-1"
environment  = "dev"
domain_name  = "sleetgale"
vpc_cidr     = "10.0.0.0/16"
subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
```

## Outputs

The configuration provides the following outputs:

- `sagemaker_domain_id`: The ID of the SageMaker Studio domain
- `sagemaker_domain_arn`: The ARN of the SageMaker Studio domain
- `sagemaker_domain_url`: The URL to access SageMaker Studio
- `sagemaker_user_profile_arn`: The ARN of the default user profile
- `sagemaker_execution_role_arn`: The ARN of the SageMaker execution role
- `sagemaker_bucket_name`: The S3 bucket name for SageMaker artifacts
- `vpc_id`: The VPC ID
- `subnet_ids`: The subnet IDs

## File Structure

```
.
├── main.tf           # Provider and Terraform configuration
├── variables.tf      # Input variables
├── network.tf        # VPC, subnets, security groups
├── iam.tf            # IAM roles and policies
├── sagemaker.tf      # SageMaker Studio domain and user profile
├── outputs.tf        # Output values
└── README.md         # This file
```

## Cost Considerations

While this configuration uses the cheapest options available:

- **JupyterServer App**: Uses "system" instance (no additional compute cost)
- **KernelGateway App**: Uses ml.t3.medium (~$0.05/hour when running)
- **Storage**: S3 standard storage costs apply
- **Data Transfer**: Standard AWS data transfer costs apply

**Important**: SageMaker Studio charges for running instances. Make sure to:
- Stop apps when not in use
- Delete the domain when no longer needed (`terraform destroy`)
- Monitor your AWS costs regularly

## Security

This configuration implements security best practices:

- Public subnets with internet gateway for SageMaker Studio connectivity
- S3 bucket with public access blocked
- IAM roles with least-privilege access
- Security groups with minimal required rules
- All resources tagged for tracking

## License

This project is open source and available under the MIT License.