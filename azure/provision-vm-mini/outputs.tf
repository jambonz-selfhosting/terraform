# Outputs for jambonz mini deployment on Azure

output "portal_url" {
  description = "URL for the jambonz portal"
  value       = "http://${var.url_portal}"
}

output "grafana_url" {
  description = "URL for the Grafana portal"
  value       = "http://grafana.${var.url_portal}"
}

output "homer_url" {
  description = "URL for the Homer portal"
  value       = "http://homer.${var.url_portal}"
}

output "server_ip" {
  description = "Server IP address - create DNS A records pointing to this IP for the domain and subdomains (api, grafana, homer, sip). This IP is stable across reboots."
  value       = azurerm_public_ip.jambonz.ip_address
}

output "resource_group_name" {
  description = "Azure resource group name"
  value       = azurerm_resource_group.jambonz.name
}

output "vm_id" {
  description = "Azure VM ID"
  value       = azurerm_linux_virtual_machine.jambonz.id
}

output "vm_name" {
  description = "Azure VM name"
  value       = azurerm_linux_virtual_machine.jambonz.name
}

output "admin_user" {
  description = "Login username for the jambonz portal"
  value       = "admin"
}

output "admin_password" {
  description = "Initial password for jambonz portal (VM ID - you will be forced to change it on first login)"
  value       = azurerm_linux_virtual_machine.jambonz.virtual_machine_id
  sensitive   = true
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh jambonz@${azurerm_public_ip.jambonz.ip_address}"
}

output "dns_records_required" {
  description = "DNS A records that need to be created"
  value = {
    "${var.url_portal}"         = azurerm_public_ip.jambonz.ip_address
    "api.${var.url_portal}"     = azurerm_public_ip.jambonz.ip_address
    "grafana.${var.url_portal}" = azurerm_public_ip.jambonz.ip_address
    "homer.${var.url_portal}"   = azurerm_public_ip.jambonz.ip_address
    "sip.${var.url_portal}"     = azurerm_public_ip.jambonz.ip_address
  }
}
