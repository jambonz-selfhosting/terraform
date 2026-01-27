# =============================================================================
# EKS Cluster Security Group
# Controls access to the EKS control plane
# =============================================================================

resource "aws_security_group" "eks_cluster" {
  name        = "${var.name_prefix}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.name_prefix}-eks-cluster-sg"
  }
}

# =============================================================================
# Internal Security Group
# Allows all traffic within the VPC for cluster communication
# =============================================================================

resource "aws_security_group" "internal" {
  name        = "${var.name_prefix}-internal-sg"
  description = "Internal cluster communication"
  vpc_id      = aws_vpc.main.id

  # Allow all traffic within VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all traffic within VPC"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.name_prefix}-internal-sg"
  }
}

# =============================================================================
# System Node Security Group
# For system nodes running LoadBalancer services (HTTP/HTTPS)
# =============================================================================

resource "aws_security_group" "system" {
  name        = "${var.name_prefix}-system-sg"
  description = "System nodes - HTTP/HTTPS for LoadBalancer services"
  vpc_id      = aws_vpc.main.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_http_cidr]
    description = "HTTP traffic"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_http_cidr]
    description = "HTTPS traffic"
  }

  # Kubernetes NodePort range
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kubernetes NodePort range"
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH access"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.name_prefix}-system-sg"
  }
}

# =============================================================================
# SIP Node Security Group
# For SIP nodes handling VoIP signaling traffic
# Note: VoIP requires public internet access - traffic comes from carriers,
# SIP trunks, and endpoints worldwide with unpredictable source IPs.
# =============================================================================

resource "aws_security_group" "sip" {
  name        = "${var.name_prefix}-sip-sg"
  description = "SIP nodes - VoIP signaling ports"
  vpc_id      = aws_vpc.main.id

  # SIP UDP 5060
  ingress {
    from_port   = 5060
    to_port     = 5060
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SIP over UDP - VoIP signaling from carriers/endpoints worldwide"
  }

  # SIP TCP 5060
  ingress {
    from_port   = 5060
    to_port     = 5060
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SIP over TCP - VoIP signaling from carriers/endpoints worldwide"
  }

  # SIP TLS 5061
  ingress {
    from_port   = 5061
    to_port     = 5061
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SIP over TLS - Secure VoIP signaling"
  }

  # SIP WSS 8443 - WebRTC signaling
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SIP over WebSocket Secure - WebRTC signaling"
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH access"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.name_prefix}-sip-sg"
  }
}

# =============================================================================
# RTP Node Security Group
# For RTP nodes handling VoIP media traffic
# Note: RTP media traffic originates from anywhere on the internet.
# =============================================================================

resource "aws_security_group" "rtp" {
  name        = "${var.name_prefix}-rtp-sg"
  description = "RTP nodes - VoIP media ports"
  vpc_id      = aws_vpc.main.id

  # RTP UDP 40000-60000
  ingress {
    from_port   = 40000
    to_port     = 60000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "RTP media - VoIP audio/video from carriers/endpoints worldwide"
  }

  # rtpengine ng protocol (DTMF events, control) UDP 2222-2223
  ingress {
    from_port   = 2222
    to_port     = 2223
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "rtpengine ng protocol - DTMF events and control"
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH access"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.name_prefix}-rtp-sg"
  }
}
