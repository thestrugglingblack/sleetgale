#!/bin/bash
# Deploy SageMaker Studio Portal
# This script builds and deploys the portal container to ECS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                               ║${NC}"
echo -e "${BLUE}║         SageMaker Studio Portal Deployment Script             ║${NC}"
echo -e "${BLUE}║                                                               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform not found. Please install Terraform first.${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install Docker first.${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites met${NC}"
echo ""

# Get Terraform outputs
echo -e "${YELLOW}📊 Getting Terraform outputs...${NC}"

ECR_REPO=$(terraform output -raw portal_ecr_repository 2>/dev/null)
CLUSTER=$(terraform output -raw portal_cluster_name 2>/dev/null)
SERVICE=$(terraform output -raw portal_service_name 2>/dev/null)
CUSTOM_DOMAIN=$(terraform output -raw custom_domain_url 2>/dev/null | sed 's|https://||')
AWS_REGION=${AWS_REGION:-us-east-1}

if [ -z "$ECR_REPO" ] || [ -z "$CLUSTER" ] || [ -z "$SERVICE" ]; then
    echo -e "${RED}❌ Could not get Terraform outputs. Have you run 'terraform apply' yet?${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Terraform outputs retrieved${NC}"
echo -e "   📦 ECR Repository: ${ECR_REPO}"
echo -e "   🎯 ECS Cluster: ${CLUSTER}"
echo -e "   ⚙️  ECS Service: ${SERVICE}"
echo -e "   🌐 Custom Domain: ${CUSTOM_DOMAIN}"
echo ""

# Login to ECR
echo -e "${YELLOW}🔐 Logging in to Amazon ECR...${NC}"
ECR_DOMAIN=$(echo $ECR_REPO | cut -d'/' -f1)

aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_DOMAIN

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to login to ECR${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Logged in to ECR${NC}"
echo ""

# Build Docker image
echo -e "${YELLOW}🔨 Building Docker image...${NC}"
cd portal

docker build -t sagemaker-portal:latest .

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to build Docker image${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker image built successfully${NC}"
echo ""

# Tag and push image
echo -e "${YELLOW}📤 Tagging and pushing image to ECR...${NC}"

docker tag sagemaker-portal:latest $ECR_REPO:latest
docker tag sagemaker-portal:latest $ECR_REPO:$(date +%Y%m%d-%H%M%S)

docker push $ECR_REPO:latest
docker push $ECR_REPO:$(date +%Y%m%d-%H%M%S)

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to push image to ECR${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Image pushed to ECR${NC}"
echo ""

cd ..

# Update ECS service
echo -e "${YELLOW}🔄 Updating ECS service...${NC}"

aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment \
  --region $AWS_REGION \
  --no-cli-pager \
  > /dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to update ECS service${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Service update initiated${NC}"
echo ""

# Wait for deployment
echo -e "${YELLOW}⏳ Waiting for service to stabilize (this may take 2-3 minutes)...${NC}"

aws ecs wait services-stable \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region $AWS_REGION

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Service deployment failed or timed out${NC}"
    echo -e "${YELLOW}💡 Check service status with:${NC}"
    echo -e "   aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $AWS_REGION"
    exit 1
fi

echo -e "${GREEN}✅ Service deployed successfully${NC}"
echo ""

# Check task status
echo -e "${YELLOW}🔍 Checking running tasks...${NC}"

TASK_COUNT=$(aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name $SERVICE \
  --region $AWS_REGION \
  --query 'length(taskArns)' \
  --output text)

echo -e "${GREEN}✅ ${TASK_COUNT} task(s) running${NC}"
echo ""

# Final output
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                               ║${NC}"
echo -e "${BLUE}║                  ${GREEN}🎉 Deployment Successful!${BLUE}                      ║${NC}"
echo -e "${BLUE}║                                                               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✨ Your SageMaker Studio portal is now available at:${NC}"
echo -e "   🌐 ${BLUE}https://${CUSTOM_DOMAIN}${NC}"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo -e "   1. Open the URL in your browser"
echo -e "   2. Click 'Launch SageMaker Studio'"
echo -e "   3. You'll be redirected to your Studio environment"
echo ""
echo -e "${YELLOW}🔧 Useful commands:${NC}"
echo -e "   View logs:    aws logs tail /ecs/${CLUSTER%-cluster}-portal --follow"
echo -e "   Check status: aws ecs describe-services --cluster $CLUSTER --services $SERVICE"
echo -e "   List tasks:   aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE"
echo ""
