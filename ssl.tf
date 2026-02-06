# SSL Certificate and Custom Domain Configuration

# Validation for custom domain configuration
locals {
  validate_custom_domain = var.enable_custom_domain && var.custom_domain_name == "" ? tobool("ERROR: When enable_custom_domain is true, custom_domain_name must be provided.") : true
}

# Route 53 Hosted Zone (optional - create new or use existing)
# NOTE: The recommended approach is to use an existing Route53 zone (set create_route53_zone = false).
# If you do create a new zone, the custom_domain_name will be used as the zone name.
# For subdomains like "sagemaker.savantpraxis.com", this creates a zone specifically for that subdomain,
# which may not be ideal. Consider using the base domain zone instead (e.g., savantpraxis.com).
resource "aws_route53_zone" "custom_domain" {
  count = var.enable_custom_domain && var.create_route53_zone ? 1 : 0
  name  = var.custom_domain_name

  tags = {
    Name = "${var.domain_name}-zone"
  }
}

# Data source for existing Route 53 zone
data "aws_route53_zone" "existing" {
  count   = var.enable_custom_domain && !var.create_route53_zone && var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
}

# Local variable for zone ID
locals {
  route53_zone_id = var.enable_custom_domain ? (
    var.create_route53_zone ? aws_route53_zone.custom_domain[0].zone_id : var.route53_zone_id
  ) : ""
}

# ACM Certificate for Custom Domain
resource "aws_acm_certificate" "sagemaker_cert" {
  count             = var.enable_custom_domain && var.certificate_arn == "" ? 1 : 0
  domain_name       = var.custom_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.domain_name}-certificate"
  }
}

# DNS validation records for ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_custom_domain && var.certificate_arn == "" ? {
    for dvo in aws_acm_certificate.sagemaker_cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.route53_zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "sagemaker_cert" {
  count                   = var.enable_custom_domain && var.certificate_arn == "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.sagemaker_cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Local variable for certificate ARN
locals {
  certificate_arn = var.enable_custom_domain ? (
    var.certificate_arn != "" ? var.certificate_arn : aws_acm_certificate.sagemaker_cert[0].arn
  ) : ""
}

# Application Load Balancer for custom domain
resource "aws_lb" "sagemaker_alb" {
  count              = var.enable_custom_domain ? 1 : 0
  name               = "${var.domain_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg[0].id]
  subnets            = aws_subnet.sagemaker_subnets[*].id

  enable_deletion_protection = false
  enable_http2               = true

  tags = {
    Name = "${var.domain_name}-alb"
  }
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  count       = var.enable_custom_domain ? 1 : 0
  name        = "${var.domain_name}-alb-sg"
  description = "Security group for SageMaker ALB"
  vpc_id      = aws_vpc.sagemaker_vpc.id

  # Allow HTTPS traffic
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  # Allow HTTP traffic (for redirect to HTTPS)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.domain_name}-alb-sg"
  }
}

# Target Group for Portal (HTTP on port 8080)
resource "aws_lb_target_group" "sagemaker_tg" {
  count       = var.enable_custom_domain ? 1 : 0
  name        = "${var.domain_name}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.sagemaker_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.domain_name}-tg"
  }
}

# HTTPS Listener for ALB
resource "aws_lb_listener" "https" {
  count             = var.enable_custom_domain ? 1 : 0
  load_balancer_arn = aws_lb.sagemaker_alb[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sagemaker_tg[0].arn
  }
}

# HTTP Listener for ALB (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  count             = var.enable_custom_domain ? 1 : 0
  load_balancer_arn = aws_lb.sagemaker_alb[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# DNS Record for custom domain pointing to ALB
resource "aws_route53_record" "sagemaker_alb" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = local.route53_zone_id
  name    = var.custom_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.sagemaker_alb[0].dns_name
    zone_id                = aws_lb.sagemaker_alb[0].zone_id
    evaluate_target_health = true
  }
}
