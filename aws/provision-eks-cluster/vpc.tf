# =============================================================================
# Data Sources
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# =============================================================================
# Local Variables
# =============================================================================

locals {
  cluster_name = "${var.name_prefix}-${var.cluster_name}"
  azs          = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)
}

# =============================================================================
# VPC
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                        = "${var.name_prefix}-vpc"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

# =============================================================================
# Internet Gateway
# Required for public subnets to access the internet
# =============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# =============================================================================
# NAT Gateway
# Required for private subnets to access the internet (egress only)
# =============================================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.sip_public[0].id  # Place NAT in first public subnet

  tags = {
    Name = "${var.name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# Private Subnets (System Node Group)
# System nodes don't need public IPs - they use NAT for egress
# =============================================================================

resource "aws_subnet" "system_private" {
  count = var.availability_zone_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                                        = "${var.name_prefix}-system-private-${local.azs[count.index]}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

# =============================================================================
# Public Subnets for SIP Node Group
# SIP nodes need public IPs for VoIP signaling
# =============================================================================

resource "aws_subnet" "sip_public" {
  count = var.availability_zone_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true  # CRITICAL for VoIP - nodes get public IPs

  tags = {
    Name                                        = "${var.name_prefix}-sip-public-${local.azs[count.index]}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

# =============================================================================
# Public Subnets for RTP Node Group
# RTP nodes need public IPs for VoIP media
# =============================================================================

resource "aws_subnet" "rtp_public" {
  count = var.availability_zone_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true  # CRITICAL for VoIP - nodes get public IPs

  tags = {
    Name                                        = "${var.name_prefix}-rtp-public-${local.azs[count.index]}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

# =============================================================================
# Route Tables
# =============================================================================

# Public route table - routes through Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

# Private route table - routes through NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

# =============================================================================
# Route Table Associations
# =============================================================================

# Associate private subnets with private route table
resource "aws_route_table_association" "system_private" {
  count = var.availability_zone_count

  subnet_id      = aws_subnet.system_private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Associate SIP subnets with public route table
resource "aws_route_table_association" "sip_public" {
  count = var.availability_zone_count

  subnet_id      = aws_subnet.sip_public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate RTP subnets with public route table
resource "aws_route_table_association" "rtp_public" {
  count = var.availability_zone_count

  subnet_id      = aws_subnet.rtp_public[count.index].id
  route_table_id = aws_route_table.public.id
}
