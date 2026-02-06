# SageMaker Studio Portal

A web portal that allows accessing SageMaker Studio through a custom domain.

## Overview

This portal application:
- Runs as a container behind the Application Load Balancer
- Generates presigned URLs for SageMaker Studio access
- Provides a user-friendly interface at your custom domain
- Handles authentication and redirection to SageMaker

## Architecture

```
User → Custom Domain (analysis.savantpraxis.com)
       ↓
     ALB (HTTPS)
       ↓
     Portal Container (ECS Fargate)
       ├── Generate presigned URL
       └── Redirect to SageMaker Studio
```

## Configuration

The portal is configured via environment variables:

- `AWS_REGION`: AWS region (default: us-east-1)
- `SAGEMAKER_DOMAIN_ID`: SageMaker domain ID  
- `DEFAULT_USER_PROFILE`: Default user profile name
- `SESSION_DURATION`: Session duration in seconds (default: 43200 = 12 hours)

## Endpoints

- `/` - Main portal page
- `/health` - Health check endpoint for ALB
- `/launch` - API endpoint to generate presigned URL
- `/users` - List available user profiles (debugging)

## Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export AWS_REGION=us-east-1
export SAGEMAKER_DOMAIN_ID=d-xxxxx
export DEFAULT_USER_PROFILE=default-user

# Run the app
python app.py
```

## Docker Build

```bash
# Build image
docker build -t sagemaker-portal .

# Run container
docker run -p 8080:8080 \
  -e AWS_REGION=us-east-1 \
  -e SAGEMAKER_DOMAIN_ID=d-xxxxx \
  -e DEFAULT_USER_PROFILE=default-user \
  sagemaker-portal
```

## Deployment

The portal is deployed automatically via Terraform as part of the Sleetgale infrastructure when `enable_custom_domain = true`.

## IAM Permissions

The portal requires these IAM permissions:
- `sagemaker:CreatePresignedDomainUrl`
- `sagemaker:ListUserProfiles`  
- `sagemaker:DescribeDomain`

These are automatically configured when deployed via Terraform.
