# Security groups for jambonz medium deployment on AWS
# Port rules match the CloudFormation template exactly

# ------------------------------------------------------------------------------
# SSH SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "ssh" {
  name        = "${var.name_prefix}-ssh-sg"
  description = "SSH access to jambonz instances"
  vpc_id      = aws_vpc.jambonz.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-ssh-sg"
  }
}

# ------------------------------------------------------------------------------
# MYSQL SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "mysql" {
  name        = "${var.name_prefix}-mysql-sg"
  description = "MySQL access from VPC"
  vpc_id      = aws_vpc.jambonz.id

  ingress {
    description = "MySQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-mysql-sg"
  }
}

# ------------------------------------------------------------------------------
# REDIS SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "redis" {
  name        = "${var.name_prefix}-redis-sg"
  description = "Redis access from VPC"
  vpc_id      = aws_vpc.jambonz.id

  ingress {
    description = "Redis from VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-redis-sg"
  }
}

# ------------------------------------------------------------------------------
# SBC SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "sbc" {
  name        = "${var.name_prefix}-sbc-sg"
  description = "SBC server security group"
  vpc_id      = aws_vpc.jambonz.id

  # SIP TCP/TLS
  ingress {
    description = "SIP TCP/TLS"
    from_port   = 5060
    to_port     = 5061
    protocol    = "tcp"
    cidr_blocks = var.allowed_sbc_cidr
  }

  # SIP UDP
  ingress {
    description = "SIP UDP"
    from_port   = 5060
    to_port     = 5060
    protocol    = "udp"
    cidr_blocks = var.allowed_sbc_cidr
  }

  # SIP WSS
  ingress {
    description = "SIP WSS"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.allowed_sbc_cidr
  }

  # RTP from external
  ingress {
    description = "RTP from external"
    from_port   = 40000
    to_port     = 60000
    protocol    = "udp"
    cidr_blocks = var.allowed_sbc_cidr
  }

  # RTP from VPC (freeswitch)
  ingress {
    description = "RTP from VPC"
    from_port   = 40000
    to_port     = 60000
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Internal HTTP (from API server)
  ingress {
    description = "Internal HTTP"
    from_port   = 3000
    to_port     = 3009
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SNS callbacks
  ingress {
    description = "SNS callbacks"
    from_port   = 3010
    to_port     = 3019
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus scrape
  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # rtpengine ng protocol
  ingress {
    description = "rtpengine ng protocol"
    from_port   = 22222
    to_port     = 22223
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # DTMF events from rtpengine sidecar
  ingress {
    description = "DTMF events"
    from_port   = 22224
    to_port     = 22233
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # rtpengine WS protocol
  ingress {
    description = "rtpengine WS"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SIP from freeswitch in VPC
  ingress {
    description = "SIP from freeswitch"
    from_port   = 5060
    to_port     = 5060
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SNS HTTP access
  ingress {
    description = "SNS HTTP"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sbc-sg"
  }
}

# ------------------------------------------------------------------------------
# FEATURE SERVER SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "feature_server" {
  name        = "${var.name_prefix}-feature-server-sg"
  description = "Feature Server security group"
  vpc_id      = aws_vpc.jambonz.id

  # HTTP from SBC/API
  ingress {
    description = "HTTP from SBC/API"
    from_port   = 3000
    to_port     = 3009
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SNS callbacks
  ingress {
    description = "SNS callbacks"
    from_port   = 3010
    to_port     = 3019
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SIP from VPC
  ingress {
    description = "SIP TCP from VPC"
    from_port   = 5060
    to_port     = 5060
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "SIP UDP from VPC"
    from_port   = 5060
    to_port     = 5060
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # RTP from VPC
  ingress {
    description = "RTP from VPC"
    from_port   = 25000
    to_port     = 40000
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # WSS from VPC
  ingress {
    description = "WSS from VPC"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-feature-server-sg"
  }
}

# ------------------------------------------------------------------------------
# WEB/MONITORING SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "web_monitoring" {
  name        = "${var.name_prefix}-web-monitoring-sg"
  description = "Web/Monitoring server security group"
  vpc_id      = aws_vpc.jambonz.id

  # HTTP/HTTPS
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
  }

  # API access from feature servers and external
  ingress {
    description = "API from feature servers"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    security_groups = [aws_security_group.feature_server.id]
  }

  ingress {
    description = "API from external"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
  }

  # upload_recordings from feature servers
  ingress {
    description = "upload_recordings from feature servers"
    from_port   = 3017
    to_port     = 3017
    protocol    = "tcp"
    security_groups = [aws_security_group.feature_server.id]
  }

  # Grafana from VPC
  ingress {
    description = "Grafana"
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # InfluxDB from VPC
  ingress {
    description = "InfluxDB"
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "InfluxDB backup"
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Homer from VPC
  ingress {
    description = "Homer webapp"
    from_port   = 9080
    to_port     = 9080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Homer HEP"
    from_port   = 9060
    to_port     = 9060
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Jaeger from VPC
  ingress {
    description = "Jaeger query"
    from_port   = 16686
    to_port     = 16686
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Jaeger collector"
    from_port   = 14268
    to_port     = 14269
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-web-monitoring-sg"
  }
}

# ------------------------------------------------------------------------------
# RECORDING ALB SECURITY GROUP (conditional)
# ------------------------------------------------------------------------------

resource "aws_security_group" "recording_alb" {
  count       = var.deploy_recording_cluster ? 1 : 0
  name        = "${var.name_prefix}-recording-alb-sg"
  description = "Recording Server ALB security group"
  vpc_id      = aws_vpc.jambonz.id

  ingress {
    description = "HTTP from allowed CIDRs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-recording-alb-sg"
  }
}

# ------------------------------------------------------------------------------
# RECORDING INSTANCE SECURITY GROUP (conditional)
# ------------------------------------------------------------------------------

resource "aws_security_group" "recording" {
  count       = var.deploy_recording_cluster ? 1 : 0
  name        = "${var.name_prefix}-recording-sg"
  description = "Recording Server instance security group"
  vpc_id      = aws_vpc.jambonz.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.recording_alb[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-recording-sg"
  }
}
