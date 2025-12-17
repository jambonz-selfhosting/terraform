# Terraform configuration for jambonz mini deployment on Exoscale
# Equivalent to the AWS CloudFormation cf-aws-mini deployment

terraform {
  required_version = ">= 1.0"

  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.54"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "exoscale" {
  key    = var.exoscale_api_key
  secret = var.exoscale_api_secret
}

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------

# Look up the jambonz template (custom image) by name or use ID directly
data "exoscale_template" "jambonz" {
  count = var.template_id == "" ? 1 : 0
  zone  = var.zone
  name  = var.template_name
}

locals {
  template_id = var.template_id != "" ? var.template_id : data.exoscale_template.jambonz[0].id
}

# ------------------------------------------------------------------------------
# RANDOM SECRETS
# ------------------------------------------------------------------------------

# Generate JWT secret (equivalent to AWS Secrets Manager secret)
# No special characters to avoid sed escaping issues in cloud-init
resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

# Generate database password
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

# ------------------------------------------------------------------------------
# SSH KEY
# ------------------------------------------------------------------------------

resource "exoscale_ssh_key" "jambonz" {
  count      = var.ssh_public_key != "" ? 1 : 0
  name       = "${var.name_prefix}-jambonz-key"
  public_key = var.ssh_public_key
}

# ------------------------------------------------------------------------------
# COMPUTE INSTANCE
# ------------------------------------------------------------------------------

resource "exoscale_compute_instance" "jambonz" {
  zone               = var.zone
  name               = "${var.name_prefix}-jambonz-mini"
  template_id        = local.template_id
  type               = var.instance_type
  disk_size          = var.disk_size
  ssh_keys           = [var.ssh_public_key != "" ? exoscale_ssh_key.jambonz[0].name : var.ssh_key_name]
  security_group_ids = [
    exoscale_security_group.jambonz.id,
    exoscale_security_group.ssh.id
  ]

  user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    url_portal      = var.url_portal
    jwt_secret      = random_password.jwt_secret.result
    db_password     = random_password.db_password.result
    instance_name   = "${var.name_prefix}-jambonz-mini"
  }))

  labels = {
    environment = var.environment
    service     = "jambonz"
    deployment  = "mini"
  }
}
