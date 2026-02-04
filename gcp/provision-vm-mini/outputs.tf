# Outputs for jambonz mini (single VM) deployment on GCP

output "portal_url" {
  description = "URL for the jambonz portal"
  value       = var.url_portal != "" ? "http://${var.url_portal}" : "http://${google_compute_address.mini.address}"
}

output "api_url" {
  description = "URL for the jambonz API"
  value       = var.url_portal != "" ? "http://${var.url_portal}/api/v1" : "http://${google_compute_address.mini.address}/api/v1"
}

output "grafana_url" {
  description = "URL for the Grafana portal"
  value       = var.url_portal != "" ? "http://grafana.${var.url_portal}" : "http://${google_compute_address.mini.address}:3010"
}

output "homer_url" {
  description = "URL for the Homer portal"
  value       = var.url_portal != "" ? "http://homer.${var.url_portal}" : "http://${google_compute_address.mini.address}:9080"
}

output "public_ip" {
  description = "Public IP address of the mini server - create DNS A records pointing to this IP"
  value       = google_compute_address.mini.address
}

output "private_ip" {
  description = "Private IP address of the mini server"
  value       = google_compute_instance.mini.network_interface[0].network_ip
}

output "instance_name" {
  description = "Mini VM name"
  value       = google_compute_instance.mini.name
}

output "portal_username" {
  description = "Login username for the jambonz portal"
  value       = "admin"
}

output "portal_password" {
  description = "Initial password for jambonz portal (the instance name - you will be forced to change it on first login)"
  value       = google_compute_instance.mini.name
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

output "ssh_connection" {
  description = "SSH connection command for the mini server"
  value       = "ssh ${var.ssh_user}@${google_compute_address.mini.address}"
}

output "dns_records_required" {
  description = "DNS A records that need to be created (only if url_portal is set)"
  value = var.url_portal != "" ? {
    "${var.url_portal}"         = google_compute_address.mini.address
    "api.${var.url_portal}"     = google_compute_address.mini.address
    "grafana.${var.url_portal}" = google_compute_address.mini.address
    "homer.${var.url_portal}"   = google_compute_address.mini.address
    "sip.${var.url_portal}"     = google_compute_address.mini.address
  } : {}
}

output "vpc_network_name" {
  description = "VPC network name"
  value       = google_compute_network.jambonz.name
}

output "subnet_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.public.name
}
