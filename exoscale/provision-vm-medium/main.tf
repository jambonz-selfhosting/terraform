# =============================================================================
# Locals
# =============================================================================

locals {
  # Generate database password if not provided
  db_password = var.mysql_password != "" ? var.mysql_password : random_password.db_password[0].result

  # SSH key configuration (ssh_keys parameter expects an array)
  ssh_key  = var.ssh_public_key != "" ? exoscale_ssh_key.jambonz[0].name : var.ssh_key_name
  ssh_keys = [local.ssh_key]

  # SSH public key content for cloud-init - read from local file if using ssh_key_name
  # User must have the public key in ~/.ssh/ directory
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : file("~/.ssh/id_rsa.pub")
}

# =============================================================================
# Random Secrets Generation
# =============================================================================

# JWT/Encryption secret (32 characters, alphanumeric only)
resource "random_password" "encryption_secret" {
  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# Database password (16 characters with special chars)
resource "random_password" "db_password" {
  count            = var.mysql_password == "" ? 1 : 0
  length           = 16
  special          = true
  override_special = "_"
  upper            = true
  lower            = true
  numeric          = true
}

# =============================================================================
# SSH Key
# =============================================================================

resource "exoscale_ssh_key" "jambonz" {
  count      = var.ssh_public_key != "" ? 1 : 0
  name       = "${var.name_prefix}-jambonz-key"
  public_key = var.ssh_public_key
}

# =============================================================================
# Private Network
# =============================================================================

resource "exoscale_private_network" "jambonz" {
  zone        = var.zone
  name        = "${var.name_prefix}-private-network"
  description = "Private network for Jambonz medium cluster"

  # Start and end IP for DHCP range
  start_ip = cidrhost(var.vpc_cidr, 10)
  end_ip   = cidrhost(var.vpc_cidr, 254)
  netmask  = cidrnetmask(var.vpc_cidr)
}

# =============================================================================
# Security Groups
# =============================================================================

# SSH Security Group
resource "exoscale_security_group" "ssh" {
  name        = "${var.name_prefix}-sg-ssh"
  description = "Security group for SSH access"
}

resource "exoscale_security_group_rule" "ssh" {
  security_group_id = exoscale_security_group.ssh.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 22
  end_port          = 22
  cidr              = var.allowed_ssh_cidr
  description       = "SSH access"
}

# Internal Security Group (allow all traffic within VPC)
resource "exoscale_security_group" "internal" {
  name        = "${var.name_prefix}-sg-internal"
  description = "Security group for internal VPC traffic"
}

resource "exoscale_security_group_rule" "internal_tcp" {
  security_group_id      = exoscale_security_group.internal.id
  type                   = "INGRESS"
  protocol               = "TCP"
  start_port             = 1
  end_port               = 65535
  user_security_group_id = exoscale_security_group.internal.id
  description            = "Internal TCP traffic"
}

resource "exoscale_security_group_rule" "internal_udp" {
  security_group_id      = exoscale_security_group.internal.id
  type                   = "INGRESS"
  protocol               = "UDP"
  start_port             = 1
  end_port               = 65535
  user_security_group_id = exoscale_security_group.internal.id
  description            = "Internal UDP traffic"
}

resource "exoscale_security_group_rule" "internal_icmp" {
  security_group_id      = exoscale_security_group.internal.id
  type                   = "INGRESS"
  protocol               = "ICMP"
  icmp_type              = 8
  icmp_code              = 0
  user_security_group_id = exoscale_security_group.internal.id
  description            = "Internal ICMP (ping)"
}

# Web/Monitoring Security Group
resource "exoscale_security_group" "web_monitoring" {
  name        = "${var.name_prefix}-sg-web-monitoring"
  description = "Security group for web/monitoring server"
}

resource "exoscale_security_group_rule" "web_http" {
  security_group_id = exoscale_security_group.web_monitoring.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 80
  end_port          = 80
  cidr              = var.allowed_http_cidr
  description       = "HTTP access"
}

resource "exoscale_security_group_rule" "web_https" {
  security_group_id = exoscale_security_group.web_monitoring.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 443
  end_port          = 443
  cidr              = var.allowed_http_cidr
  description       = "HTTPS access"
}

resource "exoscale_security_group_rule" "web_grafana" {
  security_group_id = exoscale_security_group.web_monitoring.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 3000
  end_port          = 3000
  cidr              = var.allowed_http_cidr
  description       = "Grafana access"
}

resource "exoscale_security_group_rule" "web_homer" {
  security_group_id = exoscale_security_group.web_monitoring.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 9080
  end_port          = 9080
  cidr              = var.allowed_http_cidr
  description       = "Homer web access"
}

# SBC Security Group
resource "exoscale_security_group" "sbc" {
  name        = "${var.name_prefix}-sg-sbc"
  description = "Security group for SBC servers"
}

resource "exoscale_security_group_rule" "sbc_sip_tcp" {
  security_group_id = exoscale_security_group.sbc.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 5060
  end_port          = 5060
  cidr              = var.allowed_sbc_cidr
  description       = "SIP TCP"
}

resource "exoscale_security_group_rule" "sbc_sip_udp" {
  security_group_id = exoscale_security_group.sbc.id
  type              = "INGRESS"
  protocol          = "UDP"
  start_port        = 5060
  end_port          = 5060
  cidr              = var.allowed_sbc_cidr
  description       = "SIP UDP"
}

resource "exoscale_security_group_rule" "sbc_sip_tls" {
  security_group_id = exoscale_security_group.sbc.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 5061
  end_port          = 5061
  cidr              = var.allowed_sbc_cidr
  description       = "SIP TLS"
}

resource "exoscale_security_group_rule" "sbc_sip_wss" {
  security_group_id = exoscale_security_group.sbc.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 8443
  end_port          = 8443
  cidr              = var.allowed_sbc_cidr
  description       = "SIP WebSocket Secure"
}

resource "exoscale_security_group_rule" "sbc_rtp" {
  security_group_id = exoscale_security_group.sbc.id
  type              = "INGRESS"
  protocol          = "UDP"
  start_port        = 40000
  end_port          = 60000
  cidr              = var.allowed_sbc_cidr
  description       = "RTP media"
}

resource "exoscale_security_group_rule" "sbc_http_internal" {
  security_group_id = exoscale_security_group.sbc.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 3000
  end_port          = 3009
  cidr              = var.vpc_cidr
  description       = "HTTP internal ports"
}

# Feature Server Security Group
resource "exoscale_security_group" "feature_server" {
  name        = "${var.name_prefix}-sg-feature-server"
  description = "Security group for feature servers"
}

resource "exoscale_security_group_rule" "feature_http_internal" {
  security_group_id = exoscale_security_group.feature_server.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 3000
  end_port          = 3009
  cidr              = var.vpc_cidr
  description       = "HTTP internal ports"
}

resource "exoscale_security_group_rule" "feature_sip" {
  security_group_id = exoscale_security_group.feature_server.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 5060
  end_port          = 5060
  cidr              = var.vpc_cidr
  description       = "SIP internal"
}

resource "exoscale_security_group_rule" "feature_rtp" {
  security_group_id = exoscale_security_group.feature_server.id
  type              = "INGRESS"
  protocol          = "UDP"
  start_port        = 25000
  end_port          = 40000
  cidr              = var.vpc_cidr
  description       = "RTP media internal"
}

# Recording Server Security Group
resource "exoscale_security_group" "recording" {
  name        = "${var.name_prefix}-sg-recording"
  description = "Security group for recording servers"
}

resource "exoscale_security_group_rule" "recording_http" {
  security_group_id = exoscale_security_group.recording.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 3000
  end_port          = 3000
  cidr              = var.vpc_cidr
  description       = "HTTP for health checks and uploads"
}
