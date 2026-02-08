# Outputs for jambonz large cluster deployment on Azure
#
# Large deployment has separate outputs for:
# - Web (portal/API)
# - Monitoring (Grafana/Homer/Jaeger)
# - SIP (drachtio signaling)
# - RTP (rtpengine media)
# - Feature Server (VMSS)
# - Recording (optional VMSS)

# ------------------------------------------------------------------------------
# WEB SERVER OUTPUTS
# ------------------------------------------------------------------------------

output "web_public_ip" {
  description = "Public IP address of the Web server"
  value       = azurerm_public_ip.web.ip_address
}

output "web_private_ip" {
  description = "Private IP address of the Web server"
  value       = azurerm_network_interface.web.private_ip_address
}

output "web_vm_name" {
  description = "Name of the Web server VM"
  value       = azurerm_linux_virtual_machine.web.name
}

# ------------------------------------------------------------------------------
# MONITORING SERVER OUTPUTS
# ------------------------------------------------------------------------------

output "monitoring_public_ip" {
  description = "Public IP address of the Monitoring server"
  value       = azurerm_public_ip.monitoring.ip_address
}

output "monitoring_private_ip" {
  description = "Private IP address of the Monitoring server"
  value       = azurerm_network_interface.monitoring.private_ip_address
}

output "monitoring_vm_name" {
  description = "Name of the Monitoring server VM"
  value       = azurerm_linux_virtual_machine.monitoring.name
}

# ------------------------------------------------------------------------------
# SIP SERVER OUTPUTS
# ------------------------------------------------------------------------------

output "sip_public_ips" {
  description = "Public IP addresses of the SIP servers"
  value       = azurerm_public_ip.sip[*].ip_address
}

output "sip_private_ips" {
  description = "Private IP addresses of the SIP servers"
  value       = azurerm_network_interface.sip[*].private_ip_address
}

output "sip_vm_names" {
  description = "Names of the SIP server VMs"
  value       = azurerm_linux_virtual_machine.sip[*].name
}

# ------------------------------------------------------------------------------
# RTP SERVER OUTPUTS
# ------------------------------------------------------------------------------

output "rtp_public_ips" {
  description = "Public IP addresses of the RTP servers"
  value       = azurerm_public_ip.rtp[*].ip_address
}

output "rtp_private_ips" {
  description = "Private IP addresses of the RTP servers"
  value       = azurerm_network_interface.rtp[*].private_ip_address
}

output "rtp_vm_names" {
  description = "Names of the RTP server VMs"
  value       = azurerm_linux_virtual_machine.rtp[*].name
}

# ------------------------------------------------------------------------------
# VMSS OUTPUTS
# ------------------------------------------------------------------------------

output "feature_server_vmss_name" {
  description = "Name of the Feature Server VMSS"
  value       = azurerm_linux_virtual_machine_scale_set.feature_server.name
}

output "recording_vmss_name" {
  description = "Name of the Recording Server VMSS (if deployed)"
  value       = var.deploy_recording_cluster ? azurerm_linux_virtual_machine_scale_set.recording[0].name : null
}

output "recording_lb_ip" {
  description = "Private IP of the Recording load balancer (if deployed)"
  value       = var.deploy_recording_cluster ? azurerm_lb.recording[0].private_ip_address : null
}

# ------------------------------------------------------------------------------
# DATABASE & CACHE OUTPUTS
# ------------------------------------------------------------------------------

output "mysql_server_fqdn" {
  description = "FQDN of the MySQL server"
  value       = azurerm_mysql_flexible_server.jambonz.fqdn
  sensitive   = true
}

output "redis_hostname" {
  description = "Hostname of the Redis cache"
  value       = azurerm_redis_cache.jambonz.hostname
  sensitive   = true
}

# ------------------------------------------------------------------------------
# INFRASTRUCTURE OUTPUTS
# ------------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.jambonz.name
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.jambonz.name
}

output "managed_identity_client_id" {
  description = "Client ID of the managed identity"
  value       = azurerm_user_assigned_identity.jambonz.client_id
}

# ------------------------------------------------------------------------------
# ACCESS URLS
# ------------------------------------------------------------------------------

output "portal_url" {
  description = "URL for the jambonz portal"
  value       = "http://${var.url_portal}"
}

output "api_url" {
  description = "URL for the jambonz API"
  value       = "http://${var.url_portal}/api/v1"
}

output "grafana_url" {
  description = "URL for Grafana dashboard"
  value       = "http://grafana.${var.url_portal}"
}

output "homer_url" {
  description = "URL for Homer SIP capture"
  value       = "http://homer.${var.url_portal}"
}

# ------------------------------------------------------------------------------
# DEFAULT CREDENTIALS
# ------------------------------------------------------------------------------

output "portal_username" {
  description = "Default portal admin username"
  value       = "admin"
}

output "portal_password" {
  description = "Default portal admin password (VM ID - change on first login)"
  value       = azurerm_linux_virtual_machine.web.virtual_machine_id
  sensitive   = true
}

output "grafana_username" {
  description = "Default Grafana admin username"
  value       = "admin"
}

output "grafana_password" {
  description = "Default Grafana admin password"
  value       = "admin"
}

# ------------------------------------------------------------------------------
# SSH CONNECTION COMMANDS
# ------------------------------------------------------------------------------

output "ssh_connection_web" {
  description = "SSH command to connect to the Web server"
  value       = "ssh jambonz@${azurerm_public_ip.web.ip_address}"
}

output "ssh_connection_monitoring" {
  description = "SSH command to connect to the Monitoring server"
  value       = "ssh jambonz@${azurerm_public_ip.monitoring.ip_address}"
}

output "ssh_connection_sip" {
  description = "SSH commands to connect to SIP servers"
  value       = [for ip in azurerm_public_ip.sip[*].ip_address : "ssh jambonz@${ip}"]
}

output "ssh_connection_rtp" {
  description = "SSH commands to connect to RTP servers"
  value       = [for ip in azurerm_public_ip.rtp[*].ip_address : "ssh jambonz@${ip}"]
}

# ------------------------------------------------------------------------------
# DNS RECORDS REQUIRED
# ------------------------------------------------------------------------------

output "dns_records_required" {
  description = "DNS A records that need to be created"
  value = {
    "${var.url_portal}"             = azurerm_public_ip.web.ip_address
    "api.${var.url_portal}"         = azurerm_public_ip.web.ip_address
    "public-apps.${var.url_portal}" = azurerm_public_ip.web.ip_address
    "grafana.${var.url_portal}"     = azurerm_public_ip.monitoring.ip_address
    "homer.${var.url_portal}"       = azurerm_public_ip.monitoring.ip_address
    "jaeger.${var.url_portal}"      = azurerm_public_ip.monitoring.ip_address
    "sip.${var.url_portal}"         = azurerm_public_ip.sip[0].ip_address
  }
}
