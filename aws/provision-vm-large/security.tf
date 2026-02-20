# Security groups for jambonz large deployment on AWS
# Separate SIP, RTP, Web, Monitoring, Feature Server security groups

# ------------------------------------------------------------------------------
# SSH SECURITY GROUP (shared)
# ------------------------------------------------------------------------------

resource "aws_security_group" "ssh" {
  name_prefix = "${var.name_prefix}-ssh-"
  vpc_id      = aws_vpc.jambonz.id

  ingress {
    description = "SSH"
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
    Name = "${var.name_prefix}-ssh"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# MYSQL SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "mysql" {
  name_prefix = "${var.name_prefix}-mysql-"
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
    Name = "${var.name_prefix}-mysql"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# REDIS SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "redis" {
  name_prefix = "${var.name_prefix}-redis-"
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
    Name = "${var.name_prefix}-redis"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# SBC SIP SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "sbc_sip" {
  name_prefix = "${var.name_prefix}-sbc-sip-"
  vpc_id      = aws_vpc.jambonz.id

  # SIP signaling
  ingress {
    description = "SIP TCP"
    from_port   = 5060
    to_port     = 5061
    protocol    = "tcp"
    cidr_blocks = var.allowed_sbc_cidr
  }

  ingress {
    description = "SIP UDP"
    from_port   = 5060
    to_port     = 5061
    protocol    = "udp"
    cidr_blocks = var.allowed_sbc_cidr
  }

  ingress {
    description = "WSS (WebSocket SIP)"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.allowed_sbc_cidr
  }

  # Internal HTTP/SNS ports from VPC
  ingress {
    description = "Internal HTTP"
    from_port   = 3000
    to_port     = 3009
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "SNS notification ports"
    from_port   = 3010
    to_port     = 3019
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Drachtio admin
  ingress {
    description = "Drachtio admin from VPC"
    from_port   = 9022
    to_port     = 9022
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Prometheus metrics
  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
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
    Name = "${var.name_prefix}-sbc-sip"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# SBC RTP SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "sbc_rtp" {
  name_prefix = "${var.name_prefix}-sbc-rtp-"
  vpc_id      = aws_vpc.jambonz.id

  # RTP media
  ingress {
    description = "RTP UDP"
    from_port   = 40000
    to_port     = 60000
    protocol    = "udp"
    cidr_blocks = var.allowed_sbc_cidr
  }

  # rtpengine control port from SIP servers
  ingress {
    description = "rtpengine ng control"
    from_port   = 22222
    to_port     = 22222
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # rtpengine DTMF log port
  ingress {
    description = "rtpengine DTMF"
    from_port   = 22223
    to_port     = 22233
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # rtpengine WebSocket
  ingress {
    description = "rtpengine WS"
    from_port   = 8080
    to_port     = 8080
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
    Name = "${var.name_prefix}-sbc-rtp"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# FEATURE SERVER SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "feature_server" {
  name_prefix = "${var.name_prefix}-fs-"
  vpc_id      = aws_vpc.jambonz.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 3000
    to_port     = 3009
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "SNS notification ports"
    from_port   = 3010
    to_port     = 3019
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "SIP from VPC"
    from_port   = 5060
    to_port     = 5060
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "WSS from VPC"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "RTP from VPC"
    from_port   = 25000
    to_port     = 40000
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-feature-server"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# WEB SERVER SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "web" {
  name_prefix = "${var.name_prefix}-web-"
  vpc_id      = aws_vpc.jambonz.id

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

  # API port from feature servers and external
  ingress {
    description = "API"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "API external"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
  }

  # upload_recordings from feature servers
  ingress {
    description = "upload_recordings"
    from_port   = 3017
    to_port     = 3017
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # public-apps
  ingress {
    description = "public-apps"
    from_port   = 3011
    to_port     = 3011
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
    Name = "${var.name_prefix}-web"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# MONITORING SERVER SECURITY GROUP
# ------------------------------------------------------------------------------

resource "aws_security_group" "monitoring" {
  name_prefix = "${var.name_prefix}-monitoring-"
  vpc_id      = aws_vpc.jambonz.id

  # Grafana
  ingress {
    description = "Grafana"
    from_port   = 3010
    to_port     = 3010
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # InfluxDB
  ingress {
    description = "InfluxDB HTTP"
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "InfluxDB RPC"
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Homer
  ingress {
    description = "Homer Web"
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

  # Jaeger
  ingress {
    description = "Jaeger UI"
    from_port   = 16686
    to_port     = 16686
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Jaeger collector HTTP"
    from_port   = 14268
    to_port     = 14269
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # HTTP for nginx proxy (grafana/homer subdomains)
  ingress {
    description = "HTTP"
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
    Name = "${var.name_prefix}-monitoring"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# RECORDING SECURITY GROUPS (conditional)
# ------------------------------------------------------------------------------

resource "aws_security_group" "recording_alb" {
  count       = var.deploy_recording_cluster ? 1 : 0
  name_prefix = "${var.name_prefix}-recording-alb-"
  vpc_id      = aws_vpc.jambonz.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
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
    Name = "${var.name_prefix}-recording-alb"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "recording" {
  count       = var.deploy_recording_cluster ? 1 : 0
  name_prefix = "${var.name_prefix}-recording-"
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
    Name = "${var.name_prefix}-recording"
  }

  lifecycle {
    create_before_destroy = true
  }
}
