# Custom Domain Access for SageMaker Studio

This document explains how to access SageMaker Studio through a custom domain using the web portal solution.

## Overview

Since SageMaker Studio uses dynamic presigned URLs with time-limited authentication tokens, direct proxying through an ALB isn't possible. Instead, this solution provides a **web portal** that:

1. Runs behind your custom domain (e.g., `analysis.savantpraxis.com`)
2. Authenticates users via IAM or SSO
3. Generates fresh presigned URLs for SageMaker Studio
4. Redirects users seamlessly to their Studio environment

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                          User Browser                             │
└──────────────────┬───────────────────────────────────────────────┘
                   │
                   │ HTTPS (443)
                   ▼
┌──────────────────────────────────────────────────────────────────┐
│              analysis.savantpraxis.com (Custom Domain)            │
└──────────────────┬───────────────────────────────────────────────┘
                   │
                   │ DNS Resolution
                   ▼
┌──────────────────────────────────────────────────────────────────┐
│          Application Load Balancer (ALB)                          │
│          - HTTPS Listener (Port 443)                              │
│          - SSL/TLS Termination                                    │
└──────────────────┬───────────────────────────────────────────────┘
                   │
                   │ HTTP (8080)
                   ▼
┌──────────────────────────────────────────────────────────────────┐
│          SageMaker Portal (ECS Fargate Container)                 │
│          ┌──────────────────────────────────────────────┐        │
│          │ 1. Serve web interface                       │        │
│          │ 2. AWS SDK: CreatePresignedDomainUrl()      │        │
│          │ 3. Generate fresh presigned URL             │        │
│          │ 4. Redirect user to SageMaker Studio        │        │
│          └──────────────────────────────────────────────┘        │
└──────────────────┬───────────────────────────────────────────────┘
                   │
                   │ AWS API Call
                   ▼
┌──────────────────────────────────────────────────────────────────┐
│          SageMaker Studio Domain                                  │
│          - d-xxxxx.studio.us-east-1.sagemaker.aws                │
│          - User profiles and notebooks                            │
└──────────────────────────────────────────────────────────────────┘
```

## How It Works

### Step-by-Step Flow

1. **User accesses custom domain**
   ```
   https://analysis.savantpraxis.com
   ```

2. **DNS resolves to ALB**
   - Route 53 A record points to ALB
   - ALB terminates SSL/TLS

3. **ALB forwards to portal container**
   - Portal runs on ECS Fargate
   - Container listens on port 8080
   - Health checks ensure availability

4. **Portal displays interface**
   - Shows SageMaker domain info
   - Single "Launch Studio" button
   - Clean, user-friendly UI

5. **User clicks "Launch Studio"**
   - Portal calls AWS SageMaker API
   - Generates presigned URL with 12-hour validity
   - Returns URL to browser

6. **Browser redirects to SageMaker**
   - Opens Studio in same tab
   - URL includes authentication token
   - User seamlessly enters their workspace

## Deployment

### Prerequisites

1. **Custom domain enabled**
   ```hcl
   enable_custom_domain = true
   custom_domain_name   = "analysis.savantpraxis.com"
   route53_zone_id      = "Z05687192QVMDJJL9QM6A"
   ```

2. **SSL certificate validated**
   - Certificate must be in `ISSUED` status
   - See `ACM_CERTIFICATE_ERROR_EXPLANATION.md` if needed

### Initial Setup

1. **Deploy infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

   This creates:
   - ECS cluster
   - ECR repository for portal image
   - ECS task definition
   - IAM roles with SageMaker permissions
   - Security groups
   - CloudWatch logs

2. **Build and push portal image**
   ```bash
   # Get ECR repository URL
   ECR_REPO=$(terraform output -raw portal_ecr_repository)
   AWS_REGION=$(terraform output -raw aws_region || echo "us-east-1")
   
   # Login to ECR
   aws ecr get-login-password --region $AWS_REGION | \
     docker login --username AWS --password-stdin $ECR_REPO
   
   # Build image
   cd portal
   docker build -t sagemaker-portal .
   
   # Tag and push
   docker tag sagemaker-portal:latest $ECR_REPO:latest
   docker push $ECR_REPO:latest
   ```

3. **Deploy ECS service**
   ```bash
   # Force new deployment (picks up new image)
   CLUSTER=$(terraform output -raw portal_cluster_name)
   SERVICE=$(terraform output -raw portal_service_name)
   
   aws ecs update-service \
     --cluster $CLUSTER \
     --service $SERVICE \
     --force-new-deployment \
     --region $AWS_REGION
   ```

4. **Wait for deployment**
   ```bash
   # Check service status
   aws ecs describe-services \
     --cluster $CLUSTER \
     --services $SERVICE \
     --region $AWS_REGION \
     --query 'services[0].deployments[0].status'
   
   # Check task status
   aws ecs list-tasks \
     --cluster $CLUSTER \
     --service-name $SERVICE \
     --region $AWS_REGION
   ```

5. **Verify portal is running**
   ```bash
   # Check ALB target health
   curl -I https://analysis.savantpraxis.com
   ```

### Quick Deploy Script

Save this as `deploy-portal.sh`:

```bash
#!/bin/bash
set -e

echo "🚀 Deploying SageMaker Portal..."

# Get outputs
ECR_REPO=$(terraform output -raw portal_ecr_repository)
CLUSTER=$(terraform output -raw portal_cluster_name)
SERVICE=$(terraform output -raw portal_service_name)
AWS_REGION=${AWS_REGION:-us-east-1}

echo "📦 ECR Repository: $ECR_REPO"
echo "🎯 ECS Cluster: $CLUSTER"
echo "⚙️  ECS Service: $SERVICE"

# Login to ECR
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $(echo $ECR_REPO | cut -d'/' -f1)

# Build image
echo "🔨 Building Docker image..."
cd portal
docker build -t sagemaker-portal:latest .

# Tag and push
echo "📤 Pushing to ECR..."
docker tag sagemaker-portal:latest $ECR_REPO:latest
docker push $ECR_REPO:latest

# Update service
echo "🔄 Updating ECS service..."
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment \
  --region $AWS_REGION \
  --no-cli-pager

echo "✅ Deployment initiated!"
echo "⏳ Waiting for service to stabilize (this may take 2-3 minutes)..."

aws ecs wait services-stable \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region $AWS_REGION

echo "🎉 Portal deployed successfully!"
echo "🌐 Access at: https://$(terraform output -raw custom_domain_url | sed 's|https://||')"
```

Make it executable:
```bash
chmod +x deploy-portal.sh
./deploy-portal.sh
```

## Configuration

### Environment Variables

The portal container uses these environment variables (configured in `portal.tf`):

- `AWS_REGION`: AWS region (from Terraform variable)
- `SAGEMAKER_DOMAIN_ID`: SageMaker domain ID (auto-populated)
- `DEFAULT_USER_PROFILE`: Default user profile name
  - IAM mode: `default-user`
  - SSO mode: `default-sso-user`
- `SESSION_DURATION`: Token validity in seconds (default: 43200 = 12 hours)

### Customization

To customize the portal:

1. **Modify the UI**: Edit `portal/app.py` HTML template
2. **Change session duration**: Update `SESSION_DURATION` in `portal.tf`
3. **Add authentication**: Integrate with your auth provider
4. **Add user selection**: Show dropdown of available user profiles

## Access the Portal

Once deployed:

1. **Open your custom domain**
   ```
   https://analysis.savantpraxis.com
   ```

2. **Click "Launch SageMaker Studio"**
   - Portal generates fresh presigned URL
   - Redirects to SageMaker Studio
   - You're in!

3. **Bookmark the custom domain**
   - The portal URL is static
   - Always generates fresh presigned URLs
   - No need to go through AWS Console

## Troubleshooting

### Portal Not Accessible (502/503)

1. **Check ECS service**
   ```bash
   CLUSTER=$(terraform output -raw portal_cluster_name)
   SERVICE=$(terraform output -raw portal_service_name)
   
   aws ecs describe-services \
     --cluster $CLUSTER \
     --services $SERVICE \
     --region us-east-1
   ```

2. **Check running tasks**
   ```bash
   aws ecs list-tasks \
     --cluster $CLUSTER \
     --service-name $SERVICE \
     --region us-east-1
   ```

3. **Check task logs**
   ```bash
   # Get task ARN
   TASK_ARN=$(aws ecs list-tasks \
     --cluster $CLUSTER \
     --service-name $SERVICE \
     --region us-east-1 \
     --query 'taskArns[0]' \
     --output text)
   
   # View logs
   aws logs tail /ecs/sleetgale-portal --follow
   ```

### Portal Accessible but "Launch" Fails

1. **Check IAM permissions**
   ```bash
   # Verify portal task role has SageMaker permissions
   TASK_ROLE=$(aws ecs describe-task-definition \
     --task-definition sleetgale-portal \
     --query 'taskDefinition.taskRoleArn' \
     --output text)
   
   aws iam get-role-policy \
     --role-name $(echo $TASK_ROLE | cut -d'/' -f2) \
     --policy-name sagemaker-access
   ```

2. **Check SageMaker domain**
   ```bash
   DOMAIN_ID=$(terraform output -raw sagemaker_domain_id)
   
   aws sagemaker describe-domain \
     --domain-id $DOMAIN_ID \
     --region us-east-1
   ```

3. **Test presigned URL generation manually**
   ```bash
   aws sagemaker create-presigned-domain-url \
     --domain-id $DOMAIN_ID \
     --user-profile-name default-user \
     --region us-east-1
   ```

### Container Won't Start

1. **Check ECR image exists**
   ```bash
   ECR_REPO=$(terraform output -raw portal_ecr_repository)
   
   aws ecr describe-images \
     --repository-name sleetgale-portal \
     --region us-east-1
   ```

2. **Pull and test image locally**
   ```bash
   aws ecr get-login-password --region us-east-1 | \
     docker login --username AWS --password-stdin $(echo $ECR_REPO | cut -d'/' -f1)
   
   docker pull $ECR_REPO:latest
   
   docker run -p 8080:8080 \
     -e SAGEMAKER_DOMAIN_ID=d-xxxxx \
     -e AWS_REGION=us-east-1 \
     -e DEFAULT_USER_PROFILE=default-user \
     $ECR_REPO:latest
   ```

3. **Check CloudWatch logs**
   ```bash
   aws logs tail /ecs/sleetgale-portal --follow --region us-east-1
   ```

### Health Check Failing

The ALB health check calls `/health` endpoint.

1. **Check health endpoint directly**
   ```bash
   # Get task's private IP (if in same VPC)
   TASK_IP=$(aws ecs describe-tasks \
     --cluster $CLUSTER \
     --tasks $TASK_ARN \
     --region us-east-1 \
     --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' \
     --output text)
   
   curl http://$TASK_IP:8080/health
   ```

2. **Verify security groups**
   - Portal SG must allow inbound from ALB SG on port 8080
   - ALB SG must allow outbound to Portal SG on port 8080

## Maintenance

### Update Portal Code

1. Modify `portal/app.py`
2. Run deployment script:
   ```bash
   ./deploy-portal.sh
   ```

### Update Portal Configuration

1. Modify environment variables in `portal.tf`
2. Apply Terraform changes:
   ```bash
   terraform apply
   ```
3. Force new deployment:
   ```bash
   aws ecs update-service \
     --cluster $CLUSTER \
     --service $SERVICE \
     --force-new-deployment
   ```

### Scale Portal

```bash
# Increase to 2 instances
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --desired-count 2
```

Or update in `portal.tf`:
```hcl
resource "aws_ecs_service" "portal" {
  desired_count = 2  # Change from 1
  # ...
}
```

## Security Considerations

### IAM Permissions

The portal requires:
- `sagemaker:CreatePresignedDomainUrl` - Generate Studio URLs
- `sagemaker:ListUserProfiles` - List available users
- `sagemaker:DescribeDomain` - Get domain details

These are scoped to the specific SageMaker domain only.

### Network Security

- Portal runs in private subnets (with internet gateway for AWS API calls)
- Only accessible via ALB (HTTPS)
- ALB enforces SSL/TLS
- Security groups restrict traffic flow

### Session Duration

- Default: 12 hours (43200 seconds)
- Maximum: 43200 seconds (AWS limit)
- Users need to click "Launch" again after expiry

### Adding Authentication

To add custom authentication:

1. **Modify `portal/app.py`**:
   ```python
   from flask import session, redirect, url_for
   
   @app.before_request
   def require_auth():
       if request.endpoint != 'login' and 'user' not in session:
           return redirect(url_for('login'))
   
   @app.route('/login', methods=['GET', 'POST'])
   def login():
       # Your auth logic
       pass
   ```

2. **Integrate with SSO provider** (Okta, Auth0, etc.)
3. **Use IAM Identity Center** if SSO mode is enabled

## Cost Optimization

### ECS Fargate Costs

- Portal uses: 0.25 vCPU, 0.5 GB memory
- Estimated cost: ~$6-8/month for 1 task running 24/7
- Consider scaling down to 0 during off-hours

### ECR Storage

- Portal image: ~100-200 MB
- Lifecycle policy keeps only 5 recent versions
- Minimal storage cost

### CloudWatch Logs

- 7-day retention
- Minimal log volume
- ~$0.50/month

### Total Additional Cost

Running portal adds approximately **$7-10/month** to infrastructure costs.

## Advanced Features

### Multiple User Profiles

Show dropdown to select user profile:

```python
@app.route('/')
def index():
    # List available profiles
    profiles = sagemaker.list_user_profiles(
        DomainIdEquals=SAGEMAKER_DOMAIN_ID
    )
    user_list = [p['UserProfileName'] for p in profiles['UserProfiles']]
    
    return render_template_string(
        HTML_TEMPLATE,
        users=user_list,
        # ...
    )
```

### Custom Branding

Replace the portal UI with your company's branding:
- Logo
- Colors
- Messaging
- Terms of use

### Analytics

Add analytics to track usage:
```python
import boto3

cloudwatch = boto3.client('cloudwatch')

@app.route('/launch', methods=['POST'])
def launch():
    # ... generate URL ...
    
    # Log metric
    cloudwatch.put_metric_data(
        Namespace='SageMaker/Portal',
        MetricData=[{
            'MetricName': 'StudioLaunches',
            'Value': 1,
            'Unit': 'Count'
        }]
    )
```

## Summary

The web portal solution provides:

✅ **Access SageMaker Studio via custom domain**
✅ **Seamless user experience** (single click to launch)
✅ **No manual URL generation** needed
✅ **Bookmarkable** static URL
✅ **Secure** with IAM permissions and network isolation
✅ **Cost-effective** (~$7-10/month)
✅ **Maintainable** with standard AWS services

The portal is the recommended way to enable custom domain access for SageMaker Studio while maintaining security and usability.

## See Also

- [portal/README.md](portal/README.md) - Portal application documentation
- [SETUP.md](SETUP.md) - General infrastructure setup
- [HOW_TO_ACCESS_SAGEMAKER.md](HOW_TO_ACCESS_SAGEMAKER.md) - Alternative access methods
