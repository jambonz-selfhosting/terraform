# Outputs for jambonz medium cluster deployment on Azure

output "portal_url" {
  description = "URL for the jambonz portal"
  value       = "http://${var.url_portal}"
}

output "api_url" {
  description = "URL for the jambonz API"
  value       = "http://${var.url_portal}/api/v1"
}

output "grafana_url" {
  description = "URL for the Grafana portal"
  value       = "http://grafana.${var.url_portal}"
}

output "homer_url" {
  description = "URL for the Homer portal"
  value       = "http://homer.${var.url_portal}"
}

output "web_monitoring_public_ip" {
  description = "Public IP address of the Web/Monitoring server - create DNS A records pointing to this IP"
  value       = azurerm_public_ip.web_monitoring.ip_address
}

output "sbc_public_ips" {
  description = "Public IP addresses for SBC instances (SIP traffic)"
  value       = azurerm_public_ip.sbc[*].ip_address
}

output "resource_group_name" {
  description = "Azure resource group name"
  value       = azurerm_resource_group.jambonz.name
}

output "web_monitoring_vm_name" {
  description = "Web/Monitoring VM name"
  value       = azurerm_linux_virtual_machine.web_monitoring.name
}

output "sbc_vm_names" {
  description = "SBC Virtual Machine names"
  value       = azurerm_linux_virtual_machine.sbc[*].name
}

output "feature_server_vmss_name" {
  description = "Feature Server Virtual Machine Scale Set name"
  value       = azurerm_linux_virtual_machine_scale_set.feature_server.name
}

output "recording_vmss_name" {
  description = "Recording Server Virtual Machine Scale Set name (if deployed)"
  value       = var.deploy_recording_cluster ? azurerm_linux_virtual_machine_scale_set.recording[0].name : "Not deployed"
}

output "mysql_server_fqdn" {
  description = "MySQL Flexible Server FQDN"
  value       = azurerm_mysql_flexible_server.jambonz.fqdn
  sensitive   = true
}

output "redis_hostname" {
  description = "Redis Cache hostname"
  value       = azurerm_redis_cache.jambonz.hostname
  sensitive   = true
}

output "portal_username" {
  description = "Login username for the jambonz portal"
  value       = "admin"
}

output "portal_password" {
  description = "Initial password for jambonz portal (you will be forced to change it on first login)"
  value       = azurerm_linux_virtual_machine.web_monitoring.virtual_machine_id
  sensitive   = true
}

output "grafana_username" {
  description = "Login username for the Grafana portal"
  value       = "admin"
}

output "grafana_password" {
  description = "Initial password for Grafana portal"
  value       = "admin"
}

output "ssh_connection_web_monitoring" {
  description = "SSH connection command for Web/Monitoring server"
  value       = "ssh jambonz@${azurerm_public_ip.web_monitoring.ip_address}"
}

output "dns_records_required" {
  description = "DNS A records that need to be created"
  value = {
    "${var.url_portal}"             = azurerm_public_ip.web_monitoring.ip_address
    "api.${var.url_portal}"         = azurerm_public_ip.web_monitoring.ip_address
    "grafana.${var.url_portal}"     = azurerm_public_ip.web_monitoring.ip_address
    "homer.${var.url_portal}"       = azurerm_public_ip.web_monitoring.ip_address
    "public-apps.${var.url_portal}" = azurerm_public_ip.web_monitoring.ip_address
    "sip.${var.url_portal}"         = azurerm_public_ip.sbc[0].ip_address
  }
}

output "recording_lb_ip" {
  description = "Recording Server Load Balancer IP (if deployed)"
  value       = var.deploy_recording_cluster ? azurerm_lb.recording[0].private_ip_address : "Not deployed"
}

output "key_vault_name" {
  description = "Azure Key Vault name containing secrets"
  value       = azurerm_key_vault.jambonz.name
}

output "managed_identity_client_id" {
  description = "Client ID of the managed identity for Azure resource access"
  value       = azurerm_user_assigned_identity.jambonz.client_id
}
