# Main Terraform configuration for jambonz mini (single VM) on AWS
# All-in-one deployment with local MySQL, Redis, and monitoring

# ------------------------------------------------------------------------------
# RANDOM SECRETS
# ------------------------------------------------------------------------------

resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

# ------------------------------------------------------------------------------
# SSH KEY PAIR
# ------------------------------------------------------------------------------

resource "aws_key_pair" "jambonz" {
  key_name   = "${var.name_prefix}-key"
  public_key = var.ssh_public_key
}

# ------------------------------------------------------------------------------
# VPC NETWORK
# ------------------------------------------------------------------------------

resource "aws_vpc" "jambonz" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "jambonz" {
  vpc_id = aws_vpc.jambonz.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.jambonz.id
  cidr_block = var.public_subnet_cidr

  tags = {
    Name = "${var.name_prefix}-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.jambonz.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jambonz.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# ELASTIC IP
# ------------------------------------------------------------------------------

resource "aws_eip" "mini" {
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-mini-eip"
  }
}

# ------------------------------------------------------------------------------
# SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "mini" {
  name        = "${var.name_prefix}-mini-sg"
  description = "Security group for jambonz mini all-in-one server"
  vpc_id      = aws_vpc.jambonz.id

  # SSH
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # HTTP/HTTPS
  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
  }

  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
  }

  # Web portals (Grafana, Homer, Jaeger)
  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
  }

  ingress {
    description = "Grafana (alternate port)"
    from_port   = 3010
    to_port     = 3010
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
  }

  ingress {
    description = "Homer"
    from_port   = 9080
    to_port     = 9080
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
  }

  ingress {
    description = "Jaeger"
    from_port   = 16686
    to_port     = 16686
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
  }

  # SIP signaling
  ingress {
    description = "SIP TCP"
    from_port   = 5060
    to_port     = 5060
    protocol    = "tcp"
    cidr_blocks = var.allowed_sip_cidr
  }

  ingress {
    description = "SIP TLS"
    from_port   = 5061
    to_port     = 5061
    protocol    = "tcp"
    cidr_blocks = var.allowed_sip_cidr
  }

  ingress {
    description = "SIP UDP"
    from_port   = 5060
    to_port     = 5060
    protocol    = "udp"
    cidr_blocks = var.allowed_sip_cidr
  }

  ingress {
    description = "SIP WSS"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.allowed_sip_cidr
  }

  # RTP media
  ingress {
    description = "RTP"
    from_port   = 40000
    to_port     = 60000
    protocol    = "udp"
    cidr_blocks = var.allowed_sip_cidr
  }

  # VPC internal
  ingress {
    description = "All VPC internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Egress
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-mini-sg"
  }
}

# ------------------------------------------------------------------------------
# IAM ROLE AND INSTANCE PROFILE
# ------------------------------------------------------------------------------

resource "aws_iam_role" "mini" {
  name = "${var.name_prefix}-mini-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "mini" {
  name = "${var.name_prefix}-mini-policy"
  role = aws_iam_role.mini.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.jwt.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "mini" {
  name = "${var.name_prefix}-mini-profile"
  role = aws_iam_role.mini.name
}

# ------------------------------------------------------------------------------
# SECRETS MANAGER (JWT SECRET)
# ------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${var.name_prefix}-jwt-secret"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = random_password.jwt_secret.result
}
