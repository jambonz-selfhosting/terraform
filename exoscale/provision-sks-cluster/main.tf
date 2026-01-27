# =============================================================================
# SKS Cluster
# Managed Kubernetes cluster for jambonz VoIP workloads
# =============================================================================

resource "exoscale_sks_cluster" "main" {
  zone        = var.zone
  name        = "${var.name_prefix}-${var.cluster_name}"
  description = "SKS cluster for jambonz VoIP workloads"

  cni           = var.cni
  service_level = var.service_level
  auto_upgrade  = var.auto_upgrade

  # Deploy Exoscale Cloud Controller Manager for LoadBalancer support
  exoscale_ccm = true

  # Deploy Exoscale Container Storage Interface for persistent volumes
  exoscale_csi = true
}

# =============================================================================
# Anti-Affinity Groups
# Ensures nodes in each pool are distributed across different physical hosts
# =============================================================================

resource "exoscale_anti_affinity_group" "system" {
  name        = "${var.name_prefix}-system-aag"
  description = "Anti-affinity for system nodepool - distributes nodes across hosts"
}

resource "exoscale_anti_affinity_group" "sip" {
  name        = "${var.name_prefix}-sip-aag"
  description = "Anti-affinity for SIP nodepool - distributes nodes across hosts"
}

resource "exoscale_anti_affinity_group" "rtp" {
  name        = "${var.name_prefix}-rtp-aag"
  description = "Anti-affinity for RTP nodepool - distributes nodes across hosts"
}

# =============================================================================
# System Node Pool
# General-purpose nodes for Kubernetes system components and non-VoIP workloads
# =============================================================================

resource "exoscale_sks_nodepool" "system" {
  cluster_id  = exoscale_sks_cluster.main.id
  zone        = var.zone
  name        = "system"
  description = "System node pool for general workloads and Kubernetes system components"

  instance_type = var.system_instance_type
  size          = var.system_node_count
  disk_size     = var.system_disk_size

  # Note: SKS nodes automatically receive public IPv4 addresses

  # Security groups for system nodes
  security_group_ids = [
    exoscale_security_group.internal.id,
    exoscale_security_group.system.id,
    exoscale_security_group.ssh.id,
  ]

  # HA distribution across physical hosts
  anti_affinity_group_ids = [exoscale_anti_affinity_group.system.id]

  # Labels for node selection (no taints - accepts all workloads)
  labels = {
    "pool" = "system"
  }
}

# =============================================================================
# SIP Node Pool
# Dedicated nodes for SIP signaling workloads (drachtio-server)
# Tainted to ensure only SIP pods are scheduled here
# =============================================================================

resource "exoscale_sks_nodepool" "sip" {
  cluster_id  = exoscale_sks_cluster.main.id
  zone        = var.zone
  name        = "sip"
  description = "SIP node pool for drachtio-server VoIP signaling"

  instance_type = var.sip_instance_type
  size          = var.sip_node_count
  disk_size     = var.sip_disk_size

  # Note: SKS nodes automatically receive public IPv4 addresses
  # VoIP pods use hostNetwork: true to bind directly to the node's public IP

  # Security groups for SIP nodes
  security_group_ids = [
    exoscale_security_group.internal.id,
    exoscale_security_group.sip.id,
    exoscale_security_group.ssh.id,
  ]

  # HA distribution across physical hosts
  anti_affinity_group_ids = [exoscale_anti_affinity_group.sip.id]

  # Labels for pod nodeSelector
  labels = {
    "voip-environment" = "sip"
  }

  # Taints to ensure only SIP workloads are scheduled here
  # Pods must have a matching toleration: key=sip, value=true, effect=NoSchedule
  taints = {
    "sip" = "true:NoSchedule"
  }
}

# =============================================================================
# RTP Node Pool
# Dedicated nodes for RTP media processing (rtpengine, freeswitch)
# Tainted to ensure only RTP pods are scheduled here
# =============================================================================

resource "exoscale_sks_nodepool" "rtp" {
  cluster_id  = exoscale_sks_cluster.main.id
  zone        = var.zone
  name        = "rtp"
  description = "RTP node pool for rtpengine/freeswitch media processing"

  instance_type = var.rtp_instance_type
  size          = var.rtp_node_count
  disk_size     = var.rtp_disk_size

  # Note: SKS nodes automatically receive public IPv4 addresses
  # VoIP pods use hostNetwork: true to bind directly to the node's public IP

  # Security groups for RTP nodes
  security_group_ids = [
    exoscale_security_group.internal.id,
    exoscale_security_group.rtp.id,
    exoscale_security_group.ssh.id,
  ]

  # HA distribution across physical hosts
  anti_affinity_group_ids = [exoscale_anti_affinity_group.rtp.id]

  # Labels for pod nodeSelector
  labels = {
    "voip-environment" = "rtp"
  }

  # Taints to ensure only RTP workloads are scheduled here
  # Pods must have a matching toleration: key=rtp, value=true, effect=NoSchedule
  taints = {
    "rtp" = "true:NoSchedule"
  }
}

# =============================================================================
# Kubeconfig
# Generate kubeconfig for cluster access
# =============================================================================

resource "exoscale_sks_kubeconfig" "admin" {
  cluster_id = exoscale_sks_cluster.main.id
  zone       = var.zone

  user   = "kubernetes-admin"
  groups = ["system:masters"]

  ttl_seconds = var.kubeconfig_ttl_seconds

  # Ensure nodepools are created before generating kubeconfig
  depends_on = [
    exoscale_sks_nodepool.system,
    exoscale_sks_nodepool.sip,
    exoscale_sks_nodepool.rtp,
  ]
}

# Write kubeconfig to local file
resource "local_sensitive_file" "kubeconfig" {
  filename        = "${path.module}/kubeconfig"
  content         = exoscale_sks_kubeconfig.admin.kubeconfig
  file_permission = "0600"
}
