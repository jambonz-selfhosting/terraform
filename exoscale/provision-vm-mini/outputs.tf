# Outputs for jambonz mini deployment on Exoscale

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
  value       = exoscale_compute_instance.jambonz.public_ip_address
}

output "instance_id" {
  description = "Exoscale compute instance ID"
  value       = exoscale_compute_instance.jambonz.id
}

output "instance_name" {
  description = "Exoscale compute instance name"
  value       = exoscale_compute_instance.jambonz.name
}

output "admin_user" {
  description = "Login username for the jambonz portal"
  value       = "admin"
}

output "admin_password" {
  description = "Initial password for jambonz portal (instance ID - you will be forced to change it on first login)"
  value       = exoscale_compute_instance.jambonz.id
  sensitive   = true
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh jambonz@${exoscale_compute_instance.jambonz.public_ip_address}"
}

output "dns_records_required" {
  description = "DNS A records that need to be created"
  value = {
    "${var.url_portal}"          = exoscale_compute_instance.jambonz.public_ip_address
    "api.${var.url_portal}"      = exoscale_compute_instance.jambonz.public_ip_address
    "grafana.${var.url_portal}"  = exoscale_compute_instance.jambonz.public_ip_address
    "homer.${var.url_portal}"    = exoscale_compute_instance.jambonz.public_ip_address
    "sip.${var.url_portal}"      = exoscale_compute_instance.jambonz.public_ip_address
  }
}
