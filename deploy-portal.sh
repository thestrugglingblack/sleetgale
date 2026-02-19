#!/bin/bash
# Deploy SageMaker Studio Portal (Lambda version)
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}SageMaker Studio Portal - Lambda Deployment${NC}"
echo ""

LAMBDA_NAME=$(terraform output -raw portal_lambda_function_name 2>/dev/null)
AWS_REGION=${AWS_REGION:-us-east-1}

if [ -z "$LAMBDA_NAME" ]; then
    echo "Error: Could not get Lambda function name. Run 'terraform apply' first."
    exit 1
fi

echo -e "${YELLOW}Creating deployment package...${NC}"
cd portal
zip -q lambda_handler.zip lambda_handler.py

echo -e "${YELLOW}Deploying to Lambda...${NC}"
aws lambda update-function-code \
  --function-name $LAMBDA_NAME \
  --zip-file fileb://lambda_handler.zip \
  --region $AWS_REGION \
  --no-cli-pager > /dev/null

rm lambda_handler.zip
cd ..

echo -e "${GREEN}✅ Lambda deployed successfully!${NC}"
echo ""
echo "Access your portal at: $(terraform output -raw custom_domain_url)"
echo ""
echo "Cost: ~$0.20-1/month (vs $7-10/month for ECS)"
