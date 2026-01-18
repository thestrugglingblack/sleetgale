# SageMaker image ARNs for cost-effective instances
locals {
  jupyter_server_image_arn = "arn:aws:sagemaker:${var.aws_region}:081325390199:image/jupyter-server-3"
  datascience_image_arn    = "arn:aws:sagemaker:${var.aws_region}:081325390199:image/datascience-1.0"
}

# SageMaker Studio Domain
resource "aws_sagemaker_domain" "sleetgale" {
  domain_name = var.domain_name
  auth_mode   = "IAM"
  vpc_id      = aws_vpc.sagemaker_vpc.id
  subnet_ids  = aws_subnet.sagemaker_subnets[*].id

  default_user_settings {
    execution_role  = aws_iam_role.sagemaker_execution_role.arn
    security_groups = [aws_security_group.sagemaker_sg.id]

    # Use the cheapest instance type for JupyterServer
    jupyter_server_app_settings {
      default_resource_spec {
        instance_type       = "system"
        sagemaker_image_arn = local.jupyter_server_image_arn
      }
    }

    # Use the cheapest instance type for KernelGateway
    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type       = "ml.t3.medium"
        sagemaker_image_arn = local.datascience_image_arn
      }
    }
  }

  default_space_settings {
    execution_role = aws_iam_role.sagemaker_execution_role.arn
  }

  tags = {
    Name = var.domain_name
  }
}

# SageMaker Studio User Profile
resource "aws_sagemaker_user_profile" "default_user" {
  domain_id         = aws_sagemaker_domain.sleetgale.id
  user_profile_name = "default-user"

  user_settings {
    execution_role  = aws_iam_role.sagemaker_execution_role.arn
    security_groups = [aws_security_group.sagemaker_sg.id]

    # Use the cheapest instance types
    jupyter_server_app_settings {
      default_resource_spec {
        instance_type       = "system"
        sagemaker_image_arn = local.jupyter_server_image_arn
      }
    }

    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type       = "ml.t3.medium"
        sagemaker_image_arn = local.datascience_image_arn
      }
    }
  }

  tags = {
    Name = "${var.domain_name}-default-user"
  }
}
