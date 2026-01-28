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
# Launch Templates
# Required for attaching custom security groups to EKS managed node groups
# =============================================================================

resource "aws_launch_template" "system" {
  name_prefix = "${var.name_prefix}-system-"

  vpc_security_group_ids = [
    aws_eks_cluster.main.vpc_config[0].cluster_security_group_id,
    aws_security_group.internal.id,
    aws_security_group.system.id,
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.name_prefix}-system-node" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "sip" {
  name_prefix = "${var.name_prefix}-sip-"

  vpc_security_group_ids = [
    aws_eks_cluster.main.vpc_config[0].cluster_security_group_id,
    aws_security_group.internal.id,
    aws_security_group.sip.id,
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.name_prefix}-sip-node" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "rtp" {
  name_prefix = "${var.name_prefix}-rtp-"

  vpc_security_group_ids = [
    aws_eks_cluster.main.vpc_config[0].cluster_security_group_id,
    aws_security_group.internal.id,
    aws_security_group.rtp.id,
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.name_prefix}-rtp-node" }
  }

  lifecycle {
    create_before_destroy = true
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

  # Use launch template for custom security groups
  launch_template {
    id      = aws_launch_template.system.id
    version = aws_launch_template.system.latest_version
  }

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

  # Use launch template for custom security groups
  launch_template {
    id      = aws_launch_template.sip.id
    version = aws_launch_template.sip.latest_version
  }

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

  # Use launch template for custom security groups
  launch_template {
    id      = aws_launch_template.rtp.id
    version = aws_launch_template.rtp.latest_version
  }

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

# =============================================================================
# EKS Addons
# Managed addons for core cluster functionality
# =============================================================================

# EBS CSI Driver - Required for persistent volume provisioning
# The in-tree kubernetes.io/aws-ebs provisioner was removed in Kubernetes 1.27+
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  # Resolve conflicts by overwriting existing addon configuration
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.system,
    aws_iam_role_policy_attachment.ebs_csi,
  ]

  tags = {
    Name = "${var.name_prefix}-ebs-csi-addon"
  }
}

# gp3 Storage Class - Better performance than gp2 for the same price
# Creates a storage class using the EBS CSI driver
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}

# Remove default annotation from gp2 to avoid having two default storage classes
resource "kubernetes_annotations" "gp2_non_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  force = true

  depends_on = [aws_eks_addon.ebs_csi]
}
