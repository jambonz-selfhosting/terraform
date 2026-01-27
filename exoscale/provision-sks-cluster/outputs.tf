# =============================================================================
# Cluster Outputs
# =============================================================================

output "cluster_id" {
  description = "SKS cluster ID"
  value       = exoscale_sks_cluster.main.id
}

output "cluster_name" {
  description = "SKS cluster name"
  value       = exoscale_sks_cluster.main.name
}

output "cluster_endpoint" {
  description = "SKS cluster Kubernetes API endpoint"
  value       = exoscale_sks_cluster.main.endpoint
}

output "cluster_state" {
  description = "SKS cluster state"
  value       = exoscale_sks_cluster.main.state
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = exoscale_sks_cluster.main.version
}

output "zone" {
  description = "Exoscale zone where the cluster is deployed"
  value       = var.zone
}

# =============================================================================
# Node Pool Outputs
# =============================================================================

output "system_nodepool_id" {
  description = "System nodepool ID"
  value       = exoscale_sks_nodepool.system.id
}

output "system_nodepool_instance_pool_id" {
  description = "System nodepool underlying instance pool ID"
  value       = exoscale_sks_nodepool.system.instance_pool_id
}

output "sip_nodepool_id" {
  description = "SIP nodepool ID"
  value       = exoscale_sks_nodepool.sip.id
}

output "sip_nodepool_instance_pool_id" {
  description = "SIP nodepool underlying instance pool ID"
  value       = exoscale_sks_nodepool.sip.instance_pool_id
}

output "rtp_nodepool_id" {
  description = "RTP nodepool ID"
  value       = exoscale_sks_nodepool.rtp.id
}

output "rtp_nodepool_instance_pool_id" {
  description = "RTP nodepool underlying instance pool ID"
  value       = exoscale_sks_nodepool.rtp.instance_pool_id
}

# =============================================================================
# Security Group Outputs
# =============================================================================

output "security_group_internal_id" {
  description = "Internal security group ID"
  value       = exoscale_security_group.internal.id
}

output "security_group_system_id" {
  description = "System security group ID"
  value       = exoscale_security_group.system.id
}

output "security_group_sip_id" {
  description = "SIP security group ID"
  value       = exoscale_security_group.sip.id
}

output "security_group_rtp_id" {
  description = "RTP security group ID"
  value       = exoscale_security_group.rtp.id
}

# =============================================================================
# Kubeconfig Outputs
# =============================================================================

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = local_sensitive_file.kubeconfig.filename
}

output "kubectl_command" {
  description = "Command to configure kubectl to use this cluster"
  value       = "export KUBECONFIG=${abspath(local_sensitive_file.kubeconfig.filename)}"
}

# =============================================================================
# Usage Instructions
# =============================================================================

output "usage_instructions" {
  description = "Instructions for using the cluster"
  value       = <<-EOT

    ========================================
    SKS Cluster Deployment Complete
    ========================================

    Cluster: ${exoscale_sks_cluster.main.name}
    Zone: ${var.zone}
    Endpoint: ${exoscale_sks_cluster.main.endpoint}

    Node Pools:
    - system: ${var.system_node_count} x ${var.system_instance_type} (general workloads)
    - sip:    ${var.sip_node_count} x ${var.sip_instance_type} (SIP signaling, tainted)
    - rtp:    ${var.rtp_node_count} x ${var.rtp_instance_type} (RTP media, tainted)

    To configure kubectl:

      export KUBECONFIG=${abspath(local_sensitive_file.kubeconfig.filename)}

    To verify node pools:

      kubectl get nodes --show-labels
      kubectl describe nodes | grep -A5 Taints

    ----------------------------------------
    Installing Traefik (Ingress Controller)
    ----------------------------------------

    IMPORTANT: Due to multiple node pools, Exoscale CCM requires an annotation
    specifying which instance pool should receive LoadBalancer traffic.

    1. Create the jambonz namespace:

      kubectl create namespace jambonz

    2. Install Traefik with the required annotation:

      helm repo add traefik https://traefik.github.io/charts
      helm repo update
      helm install traefik traefik/traefik --namespace jambonz \
        --set "service.annotations.service\.beta\.kubernetes\.io/exoscale-loadbalancer-service-instancepool-id=${exoscale_sks_nodepool.system.instance_pool_id}"

    3. Verify the LoadBalancer gets an external IP:

      kubectl -n jambonz get svc traefik

    ----------------------------------------
    VoIP Pod Requirements
    ----------------------------------------

    SIP pods must include:
      spec:
        hostNetwork: true
        nodeSelector:
          voip-environment: sip
        tolerations:
        - key: "sip"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"

    RTP pods must include:
      spec:
        hostNetwork: true
        nodeSelector:
          voip-environment: rtp
        tolerations:
        - key: "rtp"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"

  EOT
}
