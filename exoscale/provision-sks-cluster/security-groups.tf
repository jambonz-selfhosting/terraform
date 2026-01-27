# =============================================================================
# Internal Security Group
# Allows all cluster-internal communication between nodes
# =============================================================================

resource "exoscale_security_group" "internal" {
  name        = "${var.name_prefix}-sg-internal"
  description = "Internal cluster communication for SKS nodes"
}

resource "exoscale_security_group_rule" "internal_tcp" {
  security_group_id      = exoscale_security_group.internal.id
  type                   = "INGRESS"
  protocol               = "TCP"
  start_port             = 1
  end_port               = 65535
  user_security_group_id = exoscale_security_group.internal.id
  description            = "Internal TCP traffic between cluster nodes"
}

resource "exoscale_security_group_rule" "internal_udp" {
  security_group_id      = exoscale_security_group.internal.id
  type                   = "INGRESS"
  protocol               = "UDP"
  start_port             = 1
  end_port               = 65535
  user_security_group_id = exoscale_security_group.internal.id
  description            = "Internal UDP traffic between cluster nodes (Calico VXLAN, DNS, etc.)"
}

resource "exoscale_security_group_rule" "internal_icmp" {
  security_group_id      = exoscale_security_group.internal.id
  type                   = "INGRESS"
  protocol               = "ICMP"
  icmp_type              = 8
  icmp_code              = 0
  user_security_group_id = exoscale_security_group.internal.id
  description            = "Internal ICMP ping for health checks"
}

# =============================================================================
# SSH Security Group
# Allows SSH access to nodes for management
# =============================================================================

resource "exoscale_security_group" "ssh" {
  name        = "${var.name_prefix}-sg-ssh"
  description = "SSH access for node management"
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

# =============================================================================
# System Security Group
# For system nodes running LoadBalancer services (HTTP/HTTPS)
# =============================================================================

resource "exoscale_security_group" "system" {
  name        = "${var.name_prefix}-sg-system"
  description = "System nodes - HTTP/HTTPS for LoadBalancer services"
}

resource "exoscale_security_group_rule" "system_http" {
  security_group_id = exoscale_security_group.system.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 80
  end_port          = 80
  cidr              = var.allowed_http_cidr
  description       = "HTTP traffic"
}

resource "exoscale_security_group_rule" "system_https" {
  security_group_id = exoscale_security_group.system.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 443
  end_port          = 443
  cidr              = var.allowed_http_cidr
  description       = "HTTPS traffic"
}

resource "exoscale_security_group_rule" "system_nodeports" {
  security_group_id = exoscale_security_group.system.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 30000
  end_port          = 32767
  cidr              = "0.0.0.0/0"
  description       = "Kubernetes NodePort range for LoadBalancer services"
}

# =============================================================================
# SIP Security Group
# For SIP nodes handling VoIP signaling traffic
# Note: VoIP requires public internet access - traffic comes from carriers,
# SIP trunks, and endpoints worldwide with unpredictable source IPs.
# =============================================================================

resource "exoscale_security_group" "sip" {
  name        = "${var.name_prefix}-sg-sip"
  description = "SIP nodes - VoIP signaling ports"
}

resource "exoscale_security_group_rule" "sip_udp" {
  security_group_id = exoscale_security_group.sip.id
  type              = "INGRESS"
  protocol          = "UDP"
  start_port        = 5060
  end_port          = 5060
  cidr              = "0.0.0.0/0"
  description       = "SIP over UDP - VoIP signaling from carriers/endpoints worldwide"
}

resource "exoscale_security_group_rule" "sip_tcp" {
  security_group_id = exoscale_security_group.sip.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 5060
  end_port          = 5060
  cidr              = "0.0.0.0/0"
  description       = "SIP over TCP - VoIP signaling from carriers/endpoints worldwide"
}

resource "exoscale_security_group_rule" "sip_tls" {
  security_group_id = exoscale_security_group.sip.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 5061
  end_port          = 5061
  cidr              = "0.0.0.0/0"
  description       = "SIP over TLS - Secure VoIP signaling"
}

resource "exoscale_security_group_rule" "sip_wss" {
  security_group_id = exoscale_security_group.sip.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 8443
  end_port          = 8443
  cidr              = "0.0.0.0/0"
  description       = "SIP over WebSocket Secure - WebRTC signaling"
}

# =============================================================================
# RTP Security Group
# For RTP nodes handling VoIP media traffic
# Note: RTP media traffic originates from anywhere on the internet.
# =============================================================================

resource "exoscale_security_group" "rtp" {
  name        = "${var.name_prefix}-sg-rtp"
  description = "RTP nodes - VoIP media ports"
}

resource "exoscale_security_group_rule" "rtp_udp" {
  security_group_id = exoscale_security_group.rtp.id
  type              = "INGRESS"
  protocol          = "UDP"
  start_port        = 40000
  end_port          = 60000
  cidr              = "0.0.0.0/0"
  description       = "RTP media - VoIP audio/video from carriers/endpoints worldwide"
}
