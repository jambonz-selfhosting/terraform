# Main infrastructure for jambonz large deployment on AWS
# VPC, subnets, routing, key pairs, secrets

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

# ------------------------------------------------------------------------------
# RANDOM PASSWORDS
# ------------------------------------------------------------------------------

resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

locals {
  db_password = var.mysql_password != "" ? var.mysql_password : random_password.db_password.result
}

# ------------------------------------------------------------------------------
# SSH KEY PAIR
# ------------------------------------------------------------------------------

resource "aws_key_pair" "jambonz" {
  key_name   = "${var.name_prefix}-key"
  public_key = var.ssh_public_key
}

# ------------------------------------------------------------------------------
# VPC
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

# ------------------------------------------------------------------------------
# PUBLIC SUBNETS (2 AZs)
# ------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.jambonz.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-${count.index + 1}"
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
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# PRIVATE SUBNETS (2 AZs - for Aurora and ElastiCache)
# ------------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.jambonz.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.name_prefix}-private-${count.index + 1}"
  }
}

# ------------------------------------------------------------------------------
# SECRETS MANAGER
# ------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${var.name_prefix}-jwt-secret"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.name_prefix}-jwt-secret"
  }
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = random_password.jwt_secret.result
}
