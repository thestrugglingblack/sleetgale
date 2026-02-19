# Lambda-based Portal for SageMaker Studio
# Cost-effective serverless alternative (~$0.20-1/month vs $7-10/month ECS)

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "portal_lambda" {
  count             = var.enable_custom_domain ? 1 : 0
  name              = "/aws/lambda/${var.domain_name}-portal"
  retention_in_days = 7

  tags = {
    Name = "${var.domain_name}-portal-lambda-logs"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "portal_lambda" {
  count = var.enable_custom_domain ? 1 : 0
  name  = "${var.domain_name}-portal-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.domain_name}-portal-lambda-role"
  }
}

# IAM Policy for Lambda to Access SageMaker
resource "aws_iam_role_policy" "portal_lambda_sagemaker" {
  count = var.enable_custom_domain ? 1 : 0
  name  = "sagemaker-access"
  role  = aws_iam_role.portal_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreatePresignedDomainUrl",
          "sagemaker:ListUserProfiles",
          "sagemaker:DescribeDomain"
        ]
        Resource = [
          aws_sagemaker_domain.sleetgale.arn,
          "${aws_sagemaker_domain.sleetgale.arn}/*"
        ]
      }
    ]
  })
}

# Attach Basic Lambda Execution Policy
resource "aws_iam_role_policy_attachment" "portal_lambda_basic" {
  count      = var.enable_custom_domain ? 1 : 0
  role       = aws_iam_role.portal_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create ZIP file for Lambda deployment
data "archive_file" "portal_lambda" {
  count       = var.enable_custom_domain ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/portal/lambda_handler.py"
  output_path = "${path.module}/.terraform/portal_lambda.zip"
}

# Lambda Function
resource "aws_lambda_function" "portal" {
  count            = var.enable_custom_domain ? 1 : 0
  filename         = data.archive_file.portal_lambda[0].output_path
  function_name    = "${var.domain_name}-portal"
  role             = aws_iam_role.portal_lambda[0].arn
  handler          = "lambda_handler.lambda_handler"
  source_code_hash = data.archive_file.portal_lambda[0].output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      SAGEMAKER_DOMAIN_ID  = aws_sagemaker_domain.sleetgale.id
      DEFAULT_USER_PROFILE = var.enable_sso ? "default-sso-user" : "default-user"
      SESSION_DURATION     = "43200"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.portal_lambda,
    aws_iam_role_policy.portal_lambda_sagemaker,
    aws_iam_role_policy_attachment.portal_lambda_basic
  ]

  tags = {
    Name = "${var.domain_name}-portal-lambda"
  }
}

# Lambda Permission for ALB to invoke
resource "aws_lambda_permission" "portal_alb" {
  count         = var.enable_custom_domain ? 1 : 0
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.portal[0].function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.sagemaker_tg[0].arn
}

# Lambda Target Group Attachment
resource "aws_lb_target_group_attachment" "portal_lambda" {
  count            = var.enable_custom_domain ? 1 : 0
  target_group_arn = aws_lb_target_group.sagemaker_tg[0].arn
  target_id        = aws_lambda_function.portal[0].arn
  depends_on       = [aws_lambda_permission.portal_alb]
}
