########################################
# VPC
########################################

resource "aws_vpc" "this" {

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = var.vpc_name
    Environment = var.environment
  }
}

########################################
# IGW
########################################

resource "aws_internet_gateway" "this" {

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

########################################
# Public Subnets
########################################

resource "aws_subnet" "public" {

  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${count.index + 1}"
    Tier = "public"
  }
}

########################################
# Private Subnets
########################################

resource "aws_subnet" "private" {

  count = length(var.private_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "private-${count.index + 1}"
    Tier = "private"
  }
}

########################################
# DB Subnets
########################################

resource "aws_subnet" "database" {

  count = length(var.database_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.database_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "database-${count.index + 1}"
    Tier = "database"
  }
}

########################################
# EIP
########################################

resource "aws_eip" "nat" {

  domain = "vpc"

  tags = {
    Name = "${var.vpc_name}-nat-eip"
  }
}

########################################
# NAT Gateway
########################################

resource "aws_nat_gateway" "this" {

  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.vpc_name}-nat"
  }

  depends_on = [
    aws_internet_gateway.this
  ]
}

########################################
# Route Tables
########################################

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_route_table" "private" {

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
}

########################################
# Route Associations
########################################

resource "aws_route_table_association" "public" {

  count = length(var.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {

  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

########################################
# CloudWatch Log Group
########################################

resource "aws_cloudwatch_log_group" "flowlogs" {

  name              = "/aws/vpc/flowlogs"
  retention_in_days = 30
}

########################################
# IAM Role
########################################

resource "aws_iam_role" "flowlogs" {

  name = "vpc-flowlogs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flowlogs" {

  role = aws_iam_role.flowlogs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:*"
      ]
      Resource = "*"
    }]
  })
}

########################################
# Flow Logs
########################################

resource "aws_flow_log" "this" {

  iam_role_arn         = aws_iam_role.flowlogs.arn
  log_destination      = aws_cloudwatch_log_group.flowlogs.arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id
  log_destination_type = "cloud-watch-logs"
}

########################################
# S3 Endpoint
########################################

resource "aws_vpc_endpoint" "s3" {

  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"

  route_table_ids = [
    aws_route_table.private.id
  ]

  vpc_endpoint_type = "Gateway"
}

########################################
# SG
########################################

resource "aws_security_group" "default" {

  name   = "${var.vpc_name}-default"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_region" "current" {}