# Outputs for jambonz medium cluster deployment on GCP

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
  value       = google_compute_address.web_monitoring.address
}

output "web_monitoring_private_ip" {
  description = "Private IP address of the Web/Monitoring server"
  value       = google_compute_instance.web_monitoring.network_interface[0].network_ip
}

output "sbc_public_ips" {
  description = "Public IP addresses for SBC instances (SIP traffic)"
  value       = google_compute_address.sbc[*].address
}

output "web_monitoring_instance_name" {
  description = "Web/Monitoring VM name"
  value       = google_compute_instance.web_monitoring.name
}

output "sbc_instance_names" {
  description = "SBC VM names"
  value       = google_compute_instance.sbc[*].name
}

output "feature_server_mig_name" {
  description = "Feature Server Managed Instance Group name"
  value       = google_compute_instance_group_manager.feature_server.name
}

output "list_feature_servers_command" {
  description = "Command to list Feature Server instances with their IPs"
  value       = "gcloud compute instances list --filter=\"name~-fs-\" --format=\"table(name,zone,INTERNAL_IP,EXTERNAL_IP,status)\" --project=${var.project_id}"
}

output "scale_feature_servers_command" {
  description = "Command to scale Feature Servers (replace N with desired count)"
  value       = "gcloud compute instance-groups managed resize ${google_compute_instance_group_manager.feature_server.name} --size=N --zone=${var.zone} --project=${var.project_id}"
}

output "recording_mig_name" {
  description = "Recording Server Managed Instance Group name (if deployed)"
  value       = var.deploy_recording_cluster ? google_compute_instance_group_manager.recording[0].name : "Not deployed"
}

output "mysql_private_ip" {
  description = "Cloud SQL MySQL private IP"
  value       = google_sql_database_instance.jambonz.private_ip_address
  sensitive   = true
}

output "redis_host" {
  description = "Memorystore Redis host"
  value       = google_redis_instance.jambonz.host
  sensitive   = true
}

output "redis_port" {
  description = "Memorystore Redis port"
  value       = google_redis_instance.jambonz.port
}

output "portal_username" {
  description = "Login username for the jambonz portal"
  value       = "admin"
}

output "portal_password" {
  description = "Initial password for jambonz portal (the web-monitoring instance ID - you will be forced to change it on first login)"
  value       = google_compute_instance.web_monitoring.instance_id
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
  value       = "ssh ${var.ssh_user}@${google_compute_address.web_monitoring.address}"
}

output "dns_records_required" {
  description = "DNS A records that need to be created"
  value = {
    "${var.url_portal}"             = google_compute_address.web_monitoring.address
    "api.${var.url_portal}"         = google_compute_address.web_monitoring.address
    "grafana.${var.url_portal}"     = google_compute_address.web_monitoring.address
    "homer.${var.url_portal}"       = google_compute_address.web_monitoring.address
    "public-apps.${var.url_portal}" = google_compute_address.web_monitoring.address
    "sip.${var.url_portal}"         = google_compute_address.sbc[0].address
  }
}

output "recording_lb_ip" {
  description = "Recording Server Load Balancer IP (if deployed)"
  value       = var.deploy_recording_cluster ? google_compute_forwarding_rule.recording[0].ip_address : "Not deployed"
}

output "service_account_email" {
  description = "Service account email for jambonz VMs"
  value       = google_service_account.jambonz.email
}

output "vpc_network_name" {
  description = "VPC network name"
  value       = google_compute_network.jambonz.name
}

output "subnet_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.public.name
}