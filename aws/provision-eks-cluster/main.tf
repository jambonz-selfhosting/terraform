# =============================================================================
# EKS Cluster
# Managed Kubernetes control plane for jambonz VoIP workloads
# =============================================================================

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = concat(
      aws_subnet.system_private[*].id,
      aws_subnet.sip_public[*].id,
      aws_subnet.rtp_public[*].id
    )

    endpoint_private_access = true
    endpoint_public_access  = true

    security_group_ids = [aws_security_group.eks_cluster.id]
  }

  # Enable cluster logging
  enabled_cluster_log_types = var.cluster_log_types

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = {
    Name = local.cluster_name
  }
}

# =============================================================================
# System Node Group
# General-purpose nodes for Kubernetes system components and non-VoIP workloads
# Placed in private subnets (uses NAT Gateway for egress)
# =============================================================================

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "system"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.system_private[*].id

  scaling_config {
    desired_size = var.system_node_count
    min_size     = var.system_min_count
    max_size     = var.system_max_count
  }

  instance_types = [var.system_instance_type]
  disk_size      = var.system_disk_size

  # Labels for node selection (no taints - accepts all workloads)
  labels = {
    "pool" = "system"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_readonly,
  ]

  tags = {
    Name = "${var.name_prefix}-system-nodegroup"
  }
}

# =============================================================================
# SIP Node Group
# Dedicated nodes for SIP signaling workloads (drachtio-server)
# Placed in public subnets for direct public IP access
# Tainted to ensure only SIP pods are scheduled here
# =============================================================================

resource "aws_eks_node_group" "sip" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "sip"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.sip_public[*].id

  scaling_config {
    desired_size = var.sip_node_count
    min_size     = var.sip_min_count
    max_size     = var.sip_max_count
  }

  instance_types = [var.sip_instance_type]
  disk_size      = var.sip_disk_size

  # Labels for pod nodeSelector
  labels = {
    "voip-environment" = "sip"
  }

  # Taints to ensure only SIP workloads are scheduled here
  # Pods must have a matching toleration: key=sip, value=true, effect=NoSchedule
  taint {
    key    = "sip"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_readonly,
  ]

  tags = {
    Name = "${var.name_prefix}-sip-nodegroup"
  }
}

# =============================================================================
# RTP Node Group
# Dedicated nodes for RTP media processing (rtpengine, freeswitch)
# Placed in public subnets for direct public IP access
# Tainted to ensure only RTP pods are scheduled here
# =============================================================================

resource "aws_eks_node_group" "rtp" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "rtp"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.rtp_public[*].id

  scaling_config {
    desired_size = var.rtp_node_count
    min_size     = var.rtp_min_count
    max_size     = var.rtp_max_count
  }

  instance_types = [var.rtp_instance_type]
  disk_size      = var.rtp_disk_size

  # Labels for pod nodeSelector
  labels = {
    "voip-environment" = "rtp"
  }

  # Taints to ensure only RTP workloads are scheduled here
  # Pods must have a matching toleration: key=rtp, value=true, effect=NoSchedule
  taint {
    key    = "rtp"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_readonly,
  ]

  tags = {
    Name = "${var.name_prefix}-rtp-nodegroup"
  }
}
