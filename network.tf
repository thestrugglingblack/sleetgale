# VPC for SageMaker Studio
resource "aws_vpc" "sagemaker_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.domain_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.sagemaker_vpc.id

  tags = {
    Name = "${var.domain_name}-igw"
  }
}

# Subnets (at least 2 in different AZs required for SageMaker Studio)
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "sagemaker_subnets" {
  count                   = 2
  vpc_id                  = aws_vpc.sagemaker_vpc.id
  cidr_block              = var.subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.domain_name}-subnet-${count.index + 1}"
  }
}

# Route Table
resource "aws_route_table" "sagemaker_rt" {
  vpc_id = aws_vpc.sagemaker_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.domain_name}-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "sagemaker_rta" {
  count          = 2
  subnet_id      = aws_subnet.sagemaker_subnets[count.index].id
  route_table_id = aws_route_table.sagemaker_rt.id
}

# Security Group for SageMaker Studio
resource "aws_security_group" "sagemaker_sg" {
  name        = "${var.domain_name}-sg"
  description = "Security group for SageMaker Studio"
  vpc_id      = aws_vpc.sagemaker_vpc.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound traffic within the security group
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  tags = {
    Name = "${var.domain_name}-sg"
  }
}
