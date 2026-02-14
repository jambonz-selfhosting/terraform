# Network Security Group and rules for jambonz mini on OCI

# ------------------------------------------------------------------------------
# NETWORK SECURITY GROUP
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group" "jambonz" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.jambonz.id
  display_name   = "${var.name_prefix}-nsg"

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# ------------------------------------------------------------------------------
# EGRESS RULES - Allow all outbound traffic
# ------------------------------------------------------------------------------

resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.jambonz.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# ------------------------------------------------------------------------------
# INGRESS RULES
# ------------------------------------------------------------------------------

# SSH (22)
resource "oci_core_network_security_group_security_rule" "ingress_ssh" {
  network_security_group_id = oci_core_network_security_group.jambonz.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
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

# HTTP (80)
resource "oci_core_network_security_group_security_rule" "ingress_http" {
  network_security_group_id = oci_core_network_security_group.jambonz.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
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

# HTTPS (443)
resource "oci_core_network_security_group_security_rule" "ingress_https" {
  network_security_group_id = oci_core_network_security_group.jambonz.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
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

# SIP over UDP (5060)
resource "oci_core_network_security_group_security_rule" "ingress_sip_udp" {
  network_security_group_id = oci_core_network_security_group.jambonz.id
  direction                 = "INGRESS"
  protocol                  = "17" # UDP
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

# SIP over TCP (5060)
resource "oci_core_network_security_group_security_rule" "ingress_sip_tcp" {
  network_security_group_id = oci_core_network_security_group.jambonz.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
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

# SIP over TLS (5061)
resource "oci_core_network_security_group_security_rule" "ingress_sip_tls" {
  network_security_group_id = oci_core_network_security_group.jambonz.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
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

# SIP over WSS (8443)
resource "oci_core_network_security_group_security_rule" "ingress_sip_wss" {
  network_security_group_id = oci_core_network_security_group.jambonz.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.allowed_sip_cidr
  source_type               = "CIDR_BLOCK"
  description               = "SIP over WebSocket Secure"

  tcp_options {
    destination_port_range {
      min = 8443
      max = 8443
    }
  }
}

# RTP (40000-60000 UDP)
resource "oci_core_network_security_group_security_rule" "ingress_rtp" {
  network_security_group_id = oci_core_network_security_group.jambonz.id
  direction                 = "INGRESS"
  protocol                  = "17" # UDP
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

# Grafana (3000)
resource "oci_core_network_security_group_security_rule" "ingress_grafana" {
  network_security_group_id = oci_core_network_security_group.jambonz.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
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

# Homer (9080)
resource "oci_core_network_security_group_security_rule" "ingress_homer" {
  network_security_group_id = oci_core_network_security_group.jambonz.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
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

# Jaeger UI (16686)
resource "oci_core_network_security_group_security_rule" "ingress_jaeger" {
  network_security_group_id = oci_core_network_security_group.jambonz.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
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
