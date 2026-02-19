output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "kubeconfig" {
  description = "Kubeconfig for connecting to the cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "sip_pool_name" {
  description = "Name of the SIP node pool"
  value       = azurerm_kubernetes_cluster_node_pool.sip.name
}

output "rtp_pool_name" {
  description = "Name of the RTP node pool"
  value       = azurerm_kubernetes_cluster_node_pool.rtp.name
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "sip_subnet_id" {
  description = "ID of the SIP subnet"
  value       = azurerm_subnet.sip.id
}

output "rtp_subnet_id" {
  description = "ID of the RTP subnet"
  value       = azurerm_subnet.rtp.id
}

output "node_resource_group" {
  description = "AKS managed resource group name (MC_*)"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

# =============================================================================
# Public IP Prefix Outputs
# =============================================================================

output "sip_public_ip_prefix" {
  description = "SIP node public IP prefix CIDR (whitelist this range with carriers)"
  value       = azurerm_public_ip_prefix.sip.ip_prefix
}

output "usage_instructions" {
  description = "Instructions for using the cluster"
  value       = <<-EOT

    ============================================================
    AKS Cluster "${azurerm_kubernetes_cluster.main.name}" is ready!
    ============================================================

    1. Configure kubectl:
       az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}

    2. Verify nodes:
       kubectl get nodes --show-labels

    SIP Public IP Prefix:
    ---------------------
    ${azurerm_public_ip_prefix.sip.ip_prefix} (/${var.sip_public_ip_prefix_length})
    Whitelist this range with your SIP trunking carriers.

    RTP nodes have ephemeral public IPs (no prefix).

    To see individual node IPs:
      az vmss list-instance-public-ips \
        --resource-group ${azurerm_kubernetes_cluster.main.node_resource_group} \
        --name <vmss-name> --output table

    Post-deployment:
    ----------------
    NSG association with VMSS must still be done manually.
    See README.md for post-deployment steps.

  EOT
}
