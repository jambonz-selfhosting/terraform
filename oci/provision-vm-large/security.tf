# Network Security Groups and rules for jambonz large cluster on OCI
# Split architecture: separate SIP, RTP, Web, Monitoring NSGs

# ------------------------------------------------------------------------------
# WEB NSG (portal, API, webapp)
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "web" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.jambonz.id
  display_name   = "${var.name_prefix}-web-nsg"

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "web"
  }
}

# Egress - Allow all outbound
resource "oci_core_network_security_group_security_rule" "web_egress" {
  network_security_group_id = oci_core_network_security_group.web.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# SSH
resource "oci_core_network_security_group_security_rule" "web_ssh" {
  network_security_group_id = oci_core_network_security_group.web.id
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
resource "oci_core_network_security_group_security_rule" "web_http" {
  network_security_group_id = oci_core_network_security_group.web.id
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
resource "oci_core_network_security_group_security_rule" "web_https" {
  network_security_group_id = oci_core_network_security_group.web.id
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

# Internal - API from VCN (TCP 3002)
resource "oci_core_network_security_group_security_rule" "web_api" {
  network_security_group_id = oci_core_network_security_group.web.id
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
# MONITORING NSG (Grafana, Homer, Jaeger, InfluxDB, Redis)
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "monitoring" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.jambonz.id
  display_name   = "${var.name_prefix}-monitoring-nsg"

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "monitoring"
  }
}

# Egress - Allow all outbound
resource "oci_core_network_security_group_security_rule" "monitoring_egress" {
  network_security_group_id = oci_core_network_security_group.monitoring.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# SSH
resource "oci_core_network_security_group_security_rule" "monitoring_ssh" {
  network_security_group_id = oci_core_network_security_group.monitoring.id
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

# Grafana (TCP 3010 from web server proxy)
resource "oci_core_network_security_group_security_rule" "monitoring_grafana" {
  network_security_group_id = oci_core_network_security_group.monitoring.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Grafana from VCN"
  tcp_options {
    destination_port_range {
      min = 3010
      max = 3010
    }
  }
}

# Homer (TCP 9080 from web server proxy)
resource "oci_core_network_security_group_security_rule" "monitoring_homer" {
  network_security_group_id = oci_core_network_security_group.monitoring.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Homer from VCN"
  tcp_options {
    destination_port_range {
      min = 9080
      max = 9080
    }
  }
}

# Jaeger (TCP 16686 from web server proxy)
resource "oci_core_network_security_group_security_rule" "monitoring_jaeger_query" {
  network_security_group_id = oci_core_network_security_group.monitoring.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Jaeger query from VCN"
  tcp_options {
    destination_port_range {
      min = 16686
      max = 16686
    }
  }
}

# Jaeger collector (TCP 14268 from feature servers)
resource "oci_core_network_security_group_security_rule" "monitoring_jaeger_collector" {
  network_security_group_id = oci_core_network_security_group.monitoring.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Jaeger collector from VCN"
  tcp_options {
    destination_port_range {
      min = 14268
      max = 14268
    }
  }
}

# HEP from SIP/RTP servers (UDP 9060)
resource "oci_core_network_security_group_security_rule" "monitoring_hep" {
  network_security_group_id = oci_core_network_security_group.monitoring.id
  direction                 = "INGRESS"
  protocol                  = "17"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "HEP from SIP/RTP"
  udp_options {
    destination_port_range {
      min = 9060
      max = 9060
    }
  }
}

# InfluxDB from VCN (TCP 8086)
resource "oci_core_network_security_group_security_rule" "monitoring_influxdb" {
  network_security_group_id = oci_core_network_security_group.monitoring.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "InfluxDB from VCN"
  tcp_options {
    destination_port_range {
      min = 8086
      max = 8086
    }
  }
}

# Redis from VCN (TCP 6379)
resource "oci_core_network_security_group_security_rule" "monitoring_redis" {
  network_security_group_id = oci_core_network_security_group.monitoring.id
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

# ------------------------------------------------------------------------------
# SIP NSG (drachtio only)
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "sip" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.jambonz.id
  display_name   = "${var.name_prefix}-sip-nsg"

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "sip"
  }
}

# Egress - Allow all outbound
resource "oci_core_network_security_group_security_rule" "sip_egress" {
  network_security_group_id = oci_core_network_security_group.sip.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# SSH
resource "oci_core_network_security_group_security_rule" "sip_ssh" {
  network_security_group_id = oci_core_network_security_group.sip.id
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
resource "oci_core_network_security_group_security_rule" "sip_sip_udp" {
  network_security_group_id = oci_core_network_security_group.sip.id
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
resource "oci_core_network_security_group_security_rule" "sip_sip_tcp" {
  network_security_group_id = oci_core_network_security_group.sip.id
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
resource "oci_core_network_security_group_security_rule" "sip_sip_tls" {
  network_security_group_id = oci_core_network_security_group.sip.id
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
resource "oci_core_network_security_group_security_rule" "sip_sip_wss" {
  network_security_group_id = oci_core_network_security_group.sip.id
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

# ------------------------------------------------------------------------------
# RTP NSG (rtpengine only)
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "rtp" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.jambonz.id
  display_name   = "${var.name_prefix}-rtp-nsg"

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "rtp"
  }
}

# Egress - Allow all outbound
resource "oci_core_network_security_group_security_rule" "rtp_egress" {
  network_security_group_id = oci_core_network_security_group.rtp.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# SSH
resource "oci_core_network_security_group_security_rule" "rtp_ssh" {
  network_security_group_id = oci_core_network_security_group.rtp.id
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

# RTP media traffic (UDP 40000-60000)
resource "oci_core_network_security_group_security_rule" "rtp_rtp" {
  network_security_group_id = oci_core_network_security_group.rtp.id
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

# RTPEngine control port from SIP servers (TCP 22222)
resource "oci_core_network_security_group_security_rule" "rtp_control" {
  network_security_group_id = oci_core_network_security_group.rtp.id
  direction                 = "INGRESS"
  protocol                  = "17"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "RTPEngine control from SIP servers"
  udp_options {
    destination_port_range {
      min = 22222
      max = 22222
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

# Internal SIP from SIP servers (TCP 5060)
resource "oci_core_network_security_group_security_rule" "feature_server_sip" {
  network_security_group_id = oci_core_network_security_group.feature_server.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "SIP from SIP servers"
  tcp_options {
    destination_port_range {
      min = 5060
      max = 5060
    }
  }
}

# Internal RTP from RTP servers
resource "oci_core_network_security_group_security_rule" "feature_server_rtp" {
  network_security_group_id = oci_core_network_security_group.feature_server.id
  direction                 = "INGRESS"
  protocol                  = "17"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "RTP from RTP servers"
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
