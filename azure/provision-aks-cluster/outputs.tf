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
