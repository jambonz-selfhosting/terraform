# =============================================================================
# Cluster Outputs
# =============================================================================

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

# =============================================================================
# VPC Outputs
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (system nodes)"
  value       = aws_subnet.system_private[*].id
}

output "sip_public_subnet_ids" {
  description = "SIP public subnet IDs"
  value       = aws_subnet.sip_public[*].id
}

output "rtp_public_subnet_ids" {
  description = "RTP public subnet IDs"
  value       = aws_subnet.rtp_public[*].id
}

# =============================================================================
# Security Group Outputs
# =============================================================================

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = aws_security_group.eks_cluster.id
}

output "internal_security_group_id" {
  description = "Internal cluster communication security group ID"
  value       = aws_security_group.internal.id
}

output "system_security_group_id" {
  description = "System nodes security group ID"
  value       = aws_security_group.system.id
}

output "sip_security_group_id" {
  description = "SIP nodes security group ID"
  value       = aws_security_group.sip.id
}

output "rtp_security_group_id" {
  description = "RTP nodes security group ID"
  value       = aws_security_group.rtp.id
}

# =============================================================================
# Elastic IP Outputs
# =============================================================================

output "sip_eip_public_ip" {
  description = "Elastic IP address for SIP node"
  value       = aws_eip.sip.public_ip
}

output "rtp_eip_public_ip" {
  description = "Elastic IP address for RTP node"
  value       = aws_eip.rtp.public_ip
}

output "sip_eip_allocation_id" {
  description = "SIP EIP allocation ID"
  value       = aws_eip.sip.allocation_id
}

output "rtp_eip_allocation_id" {
  description = "RTP EIP allocation ID"
  value       = aws_eip.rtp.allocation_id
}

# =============================================================================
# IAM Outputs
# =============================================================================

output "eks_cluster_role_arn" {
  description = "IAM role ARN for EKS cluster"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  description = "IAM role ARN for EKS node groups"
  value       = aws_iam_role.eks_node.arn
}

# =============================================================================
# Node Group Outputs
# =============================================================================

output "system_node_group_name" {
  description = "System node group name"
  value       = aws_eks_node_group.system.node_group_name
}

output "sip_node_group_name" {
  description = "SIP node group name"
  value       = aws_eks_node_group.sip.node_group_name
}

output "rtp_node_group_name" {
  description = "RTP node group name"
  value       = aws_eks_node_group.rtp.node_group_name
}

# =============================================================================
# Usage Instructions
# =============================================================================

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.main.name}"
}

output "usage_instructions" {
  description = "Instructions for using the cluster"
  value       = <<-EOT

    ============================================================
    EKS Cluster "${aws_eks_cluster.main.name}" is ready!
    ============================================================

    1. Configure kubectl:
       aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.main.name}

    2. Verify nodes:
       kubectl get nodes --show-labels

    3. Check taints:
       kubectl describe nodes | grep -A3 Taints

    Node Pools:
    -----------
    - system: General workloads (private subnets)
      Label: pool=system

    - sip: SIP signaling (public subnets with public IPs)
      Label: voip-environment=sip
      Taint: sip=true:NoSchedule

    - rtp: RTP media (public subnets with public IPs)
      Label: voip-environment=rtp
      Taint: rtp=true:NoSchedule

    VoIP Pod Requirements:
    ----------------------
    SIP pods need:
      nodeSelector:
        voip-environment: sip
      tolerations:
        - key: sip
          value: "true"
          effect: NoSchedule
      hostNetwork: true

    RTP pods need:
      nodeSelector:
        voip-environment: rtp
      tolerations:
        - key: rtp
          value: "true"
          effect: NoSchedule
      hostNetwork: true

  EOT
}
