# Network Security Groups and rules for jambonz medium cluster on OCI

# ------------------------------------------------------------------------------
# WEB/MONITORING NSG
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "web_monitoring" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.jambonz.id
  display_name   = "${var.name_prefix}-web-monitoring-nsg"

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "web-monitoring"
  }
}

# Egress - Allow all outbound
resource "oci_core_network_security_group_security_rule" "web_monitoring_egress" {
  network_security_group_id = oci_core_network_security_group.web_monitoring.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# SSH
resource "oci_core_network_security_group_security_rule" "web_monitoring_ssh" {
  network_security_group_id = oci_core_network_security_group.web_monitoring.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_ssh_cidr
  source_type               = "CIDR_BLOCK"
  description               = "SSH access"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# HTTP
resource "oci_core_network_security_group_security_rule" "web_monitoring_http" {
  network_security_group_id = oci_core_network_security_group.web_monitoring.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_http_cidr
  source_type               = "CIDR_BLOCK"
  description               = "HTTP access"
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

# HTTPS
resource "oci_core_network_security_group_security_rule" "web_monitoring_https" {
  network_security_group_id = oci_core_network_security_group.web_monitoring.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_http_cidr
  source_type               = "CIDR_BLOCK"
  description               = "HTTPS access"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# Grafana
resource "oci_core_network_security_group_security_rule" "web_monitoring_grafana" {
  network_security_group_id = oci_core_network_security_group.web_monitoring.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_http_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Grafana dashboard"
  tcp_options {
    destination_port_range {
      min = 3000
      max = 3000
    }
  }
}

# Homer
resource "oci_core_network_security_group_security_rule" "web_monitoring_homer" {
  network_security_group_id = oci_core_network_security_group.web_monitoring.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_http_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Homer SIP capture"
  tcp_options {
    destination_port_range {
      min = 9080
      max = 9080
    }
  }
}

# Jaeger
resource "oci_core_network_security_group_security_rule" "web_monitoring_jaeger" {
  network_security_group_id = oci_core_network_security_group.web_monitoring.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_http_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Jaeger tracing UI"
  tcp_options {
    destination_port_range {
      min = 16686
      max = 16686
    }
  }
}

# Internal - HEP from SBC (UDP 9060)
resource "oci_core_network_security_group_security_rule" "web_monitoring_hep" {
  network_security_group_id = oci_core_network_security_group.web_monitoring.id
  direction                 = "INGRESS"
  protocol                  = "17"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "HEP from SBC"
  udp_options {
    destination_port_range {
      min = 9060
      max = 9060
    }
  }
}

# Internal - API from VCN (TCP 3002)
resource "oci_core_network_security_group_security_rule" "web_monitoring_api" {
  network_security_group_id = oci_core_network_security_group.web_monitoring.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "API from internal"
  tcp_options {
    destination_port_range {
      min = 3002
      max = 3002
    }
  }
}

# ------------------------------------------------------------------------------
# SBC NSG
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "sbc" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.jambonz.id
  display_name   = "${var.name_prefix}-sbc-nsg"

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "sbc"
  }
}

# Egress - Allow all outbound
resource "oci_core_network_security_group_security_rule" "sbc_egress" {
  network_security_group_id = oci_core_network_security_group.sbc.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# SSH
resource "oci_core_network_security_group_security_rule" "sbc_ssh" {
  network_security_group_id = oci_core_network_security_group.sbc.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_ssh_cidr
  source_type               = "CIDR_BLOCK"
  description               = "SSH access"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# SIP UDP
resource "oci_core_network_security_group_security_rule" "sbc_sip_udp" {
  network_security_group_id = oci_core_network_security_group.sbc.id
  direction                 = "INGRESS"
  protocol                  = "17"
  source                    = var.allowed_sip_cidr
  source_type               = "CIDR_BLOCK"
  description               = "SIP over UDP"
  udp_options {
    destination_port_range {
      min = 5060
      max = 5060
    }
  }
}

# SIP TCP
resource "oci_core_network_security_group_security_rule" "sbc_sip_tcp" {
  network_security_group_id = oci_core_network_security_group.sbc.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_sip_cidr
  source_type               = "CIDR_BLOCK"
  description               = "SIP over TCP"
  tcp_options {
    destination_port_range {
      min = 5060
      max = 5060
    }
  }
}

# SIP TLS
resource "oci_core_network_security_group_security_rule" "sbc_sip_tls" {
  network_security_group_id = oci_core_network_security_group.sbc.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_sip_cidr
  source_type               = "CIDR_BLOCK"
  description               = "SIP over TLS"
  tcp_options {
    destination_port_range {
      min = 5061
      max = 5061
    }
  }
}

# SIP WSS
resource "oci_core_network_security_group_security_rule" "sbc_sip_wss" {
  network_security_group_id = oci_core_network_security_group.sbc.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_sip_cidr
  source_type               = "CIDR_BLOCK"
  description               = "SIP over WSS"
  tcp_options {
    destination_port_range {
      min = 8443
      max = 8443
    }
  }
}

# RTP
resource "oci_core_network_security_group_security_rule" "sbc_rtp" {
  network_security_group_id = oci_core_network_security_group.sbc.id
  direction                 = "INGRESS"
  protocol                  = "17"
  source                    = var.allowed_rtp_cidr
  source_type               = "CIDR_BLOCK"
  description               = "RTP media traffic"
  udp_options {
    destination_port_range {
      min = 40000
      max = 60000
    }
  }
}

# ------------------------------------------------------------------------------
# FEATURE SERVER NSG
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "feature_server" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.jambonz.id
  display_name   = "${var.name_prefix}-feature-server-nsg"

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "feature-server"
  }
}

# Egress - Allow all outbound
resource "oci_core_network_security_group_security_rule" "feature_server_egress" {
  network_security_group_id = oci_core_network_security_group.feature_server.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# SSH
resource "oci_core_network_security_group_security_rule" "feature_server_ssh" {
  network_security_group_id = oci_core_network_security_group.feature_server.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_ssh_cidr
  source_type               = "CIDR_BLOCK"
  description               = "SSH access"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# Internal SIP from SBC (TCP 5060)
resource "oci_core_network_security_group_security_rule" "feature_server_sip" {
  network_security_group_id = oci_core_network_security_group.feature_server.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "SIP from SBC"
  tcp_options {
    destination_port_range {
      min = 5060
      max = 5060
    }
  }
}

# Internal RTP from SBC
resource "oci_core_network_security_group_security_rule" "feature_server_rtp" {
  network_security_group_id = oci_core_network_security_group.feature_server.id
  direction                 = "INGRESS"
  protocol                  = "17"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "RTP from SBC"
  udp_options {
    destination_port_range {
      min = 20000
      max = 40000
    }
  }
}

# ------------------------------------------------------------------------------
# RECORDING NSG (conditional)
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "recording" {
  count = var.deploy_recording_cluster ? 1 : 0

  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.jambonz.id
  display_name   = "${var.name_prefix}-recording-nsg"

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "recording"
  }
}

# Egress - Allow all outbound
resource "oci_core_network_security_group_security_rule" "recording_egress" {
  count = var.deploy_recording_cluster ? 1 : 0

  network_security_group_id = oci_core_network_security_group.recording[0].id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# SSH
resource "oci_core_network_security_group_security_rule" "recording_ssh" {
  count = var.deploy_recording_cluster ? 1 : 0

  network_security_group_id = oci_core_network_security_group.recording[0].id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.allowed_ssh_cidr
  source_type               = "CIDR_BLOCK"
  description               = "SSH access"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# Internal WebSocket from Feature Server
resource "oci_core_network_security_group_security_rule" "recording_ws" {
  count = var.deploy_recording_cluster ? 1 : 0

  network_security_group_id = oci_core_network_security_group.recording[0].id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "WebSocket from Feature Server"
  tcp_options {
    destination_port_range {
      min = 3000
      max = 3000
    }
  }
}

# ------------------------------------------------------------------------------
# DATABASE NSG
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "database" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.jambonz.id
  display_name   = "${var.name_prefix}-database-nsg"

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "database"
  }
}

# MySQL from VCN
resource "oci_core_network_security_group_security_rule" "database_mysql" {
  network_security_group_id = oci_core_network_security_group.database.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "MySQL from VCN"
  tcp_options {
    destination_port_range {
      min = 3306
      max = 3306
    }
  }
}

# Redis from VCN
resource "oci_core_network_security_group_security_rule" "database_redis" {
  network_security_group_id = oci_core_network_security_group.database.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Redis from VCN"
  tcp_options {
    destination_port_range {
      min = 6379
      max = 6379
    }
  }
}
