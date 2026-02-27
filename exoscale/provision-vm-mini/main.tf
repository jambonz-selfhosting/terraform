# Terraform configuration for jambonz mini deployment on Exoscale

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------

data "exoscale_template" "jambonz_mini" {
  zone       = var.zone
  name       = "jambonz-mini-v${var.jambonz_version}"
  visibility = "private"
}

# ------------------------------------------------------------------------------
# SECURITY GROUPS
# ------------------------------------------------------------------------------

# Main jambonz security group
resource "exoscale_security_group" "jambonz" {
  name = "${var.name_prefix}-jambonz"
}

# SSH security group
resource "exoscale_security_group" "ssh" {
  name = "${var.name_prefix}-ssh"
}

# SIP over UDP (5060)
resource "exoscale_security_group_rule" "sip_udp" {
  security_group_id = exoscale_security_group.jambonz.id
  type              = "INGRESS"
  protocol          = "UDP"
  cidr              = var.allowed_sip_cidr
  start_port        = 5060
  end_port          = 5060
  description       = "SIP over UDP"
}

# SIP over TCP (5060)
resource "exoscale_security_group_rule" "sip_tcp" {
  security_group_id = exoscale_security_group.jambonz.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = var.allowed_sip_cidr
  start_port        = 5060
  end_port          = 5060
  description       = "SIP over TCP"
}

# SIP over TLS (5061)
resource "exoscale_security_group_rule" "sip_tls" {
  security_group_id = exoscale_security_group.jambonz.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = var.allowed_sip_cidr
  start_port        = 5061
  end_port          = 5061
  description       = "SIP over TLS"
}

# SIP over WSS (8443)
resource "exoscale_security_group_rule" "sip_wss" {
  security_group_id = exoscale_security_group.jambonz.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = var.allowed_sip_cidr
  start_port        = 8443
  end_port          = 8443
  description       = "SIP over WSS"
}

# RTP (40000-60000)
resource "exoscale_security_group_rule" "rtp" {
  security_group_id = exoscale_security_group.jambonz.id
  type              = "INGRESS"
  protocol          = "UDP"
  cidr              = var.allowed_rtp_cidr
  start_port        = 40000
  end_port          = 60000
  description       = "RTP media"
}

# HTTP (80)
resource "exoscale_security_group_rule" "http" {
  security_group_id = exoscale_security_group.jambonz.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = var.allowed_http_cidr
  start_port        = 80
  end_port          = 80
  description       = "HTTP"
}

# HTTPS (443)
resource "exoscale_security_group_rule" "https" {
  security_group_id = exoscale_security_group.jambonz.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = var.allowed_http_cidr
  start_port        = 443
  end_port          = 443
  description       = "HTTPS"
}

# Homer (9080)
resource "exoscale_security_group_rule" "homer" {
  security_group_id = exoscale_security_group.jambonz.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = var.allowed_http_cidr
  start_port        = 9080
  end_port          = 9080
  description       = "Homer"
}

# Grafana (3000)
resource "exoscale_security_group_rule" "grafana" {
  security_group_id = exoscale_security_group.jambonz.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = var.allowed_http_cidr
  start_port        = 3000
  end_port          = 3000
  description       = "Grafana"
}

# SSH (22)
resource "exoscale_security_group_rule" "ssh" {
  security_group_id = exoscale_security_group.ssh.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = var.allowed_ssh_cidr
  start_port        = 22
  end_port          = 22
  description       = "SSH"
}
