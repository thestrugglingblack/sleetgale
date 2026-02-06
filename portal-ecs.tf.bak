# ECS Cluster for SageMaker Portal
resource "aws_ecs_cluster" "portal" {
  count = var.enable_custom_domain ? 1 : 0
  name  = "${var.domain_name}-portal-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.domain_name}-portal-cluster"
  }
}

# CloudWatch Log Group for Portal
resource "aws_cloudwatch_log_group" "portal" {
  count             = var.enable_custom_domain ? 1 : 0
  name              = "/ecs/${var.domain_name}-portal"
  retention_in_days = 7

  tags = {
    Name = "${var.domain_name}-portal-logs"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "portal_execution_role" {
  count = var.enable_custom_domain ? 1 : 0
  name  = "${var.domain_name}-portal-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.domain_name}-portal-execution-role"
  }
}

# Attach ECS Task Execution Policy
resource "aws_iam_role_policy_attachment" "portal_execution_policy" {
  count      = var.enable_custom_domain ? 1 : 0
  role       = aws_iam_role.portal_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task (Portal Application)
resource "aws_iam_role" "portal_task_role" {
  count = var.enable_custom_domain ? 1 : 0
  name  = "${var.domain_name}-portal-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.domain_name}-portal-task-role"
  }
}

# IAM Policy for Portal to Access SageMaker
resource "aws_iam_role_policy" "portal_sagemaker_policy" {
  count = var.enable_custom_domain ? 1 : 0
  name  = "sagemaker-access"
  role  = aws_iam_role.portal_task_role[0].id

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

# Security Group for Portal Tasks
resource "aws_security_group" "portal_sg" {
  count       = var.enable_custom_domain ? 1 : 0
  name        = "${var.domain_name}-portal-sg"
  description = "Security group for SageMaker portal ECS tasks"
  vpc_id      = aws_vpc.sagemaker_vpc.id

  # Allow inbound traffic from ALB
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg[0].id]
    description     = "HTTP from ALB"
  }

  # Allow all outbound traffic (for AWS API calls)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.domain_name}-portal-sg"
  }
}

# ECR Repository for Portal Image
resource "aws_ecr_repository" "portal" {
  count                = var.enable_custom_domain ? 1 : 0
  name                 = "${var.domain_name}-portal"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.domain_name}-portal-repo"
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "portal" {
  count      = var.enable_custom_domain ? 1 : 0
  repository = aws_ecr_repository.portal[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "portal" {
  count                    = var.enable_custom_domain ? 1 : 0
  family                   = "${var.domain_name}-portal"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.portal_execution_role[0].arn
  task_role_arn            = aws_iam_role.portal_task_role[0].arn

  container_definitions = jsonencode([
    {
      name      = "portal"
      image     = "${aws_ecr_repository.portal[0].repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "SAGEMAKER_DOMAIN_ID"
          value = aws_sagemaker_domain.sleetgale.id
        },
        {
          name  = "DEFAULT_USER_PROFILE"
          value = var.enable_sso ? "default-sso-user" : "default-user"
        },
        {
          name  = "SESSION_DURATION"
          value = "43200"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.portal[0].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "portal"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.domain_name}-portal-task"
  }
}

# ECS Service
resource "aws_ecs_service" "portal" {
  count           = var.enable_custom_domain ? 1 : 0
  name            = "${var.domain_name}-portal-service"
  cluster         = aws_ecs_cluster.portal[0].id
  task_definition = aws_ecs_task_definition.portal[0].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.sagemaker_subnets[*].id
    security_groups  = [aws_security_group.portal_sg[0].id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.sagemaker_tg[0].arn
    container_name   = "portal"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.https,
    aws_iam_role_policy.portal_sagemaker_policy
  ]

  tags = {
    Name = "${var.domain_name}-portal-service"
  }
}
