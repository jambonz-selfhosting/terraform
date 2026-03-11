# =============================================================================
# Service URLs
# =============================================================================

output "portal_url" {
  description = "Portal URL"
  value       = "http://${var.url_portal}"
}

output "api_url" {
  description = "API URL"
  value       = "http://api.${var.url_portal}"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://grafana.${var.url_portal}"
}

output "homer_url" {
  description = "Homer URL"
  value       = "http://homer.${var.url_portal}"
}

output "sip_domain" {
  description = "SIP domain"
  value       = "sip.${var.url_portal}"
}

# =============================================================================
# Provider Info
# =============================================================================

output "zone" {
  description = "Exoscale zone"
  value       = var.zone
}

# =============================================================================
# Public IPs
# =============================================================================

output "web_monitoring_public_ip" {
  description = "Web/Monitoring server public IP"
  value       = exoscale_elastic_ip.web_monitoring.ip_address
}

output "sbc_public_ips" {
  description = "SBC server public IPs"
  value       = [for eip in exoscale_elastic_ip.sbc : eip.ip_address]
}

# =============================================================================
# Instance Pool IDs (for test script discovery)
# =============================================================================

output "feature_server_pool_id" {
  description = "Feature server instance pool ID"
  value       = exoscale_instance_pool.feature_server.id
}

output "recording_server_pool_id" {
  description = "Recording server instance pool ID (if deployed)"
  value       = var.deploy_recording_cluster ? exoscale_instance_pool.recording[0].id : null
}

output "recording_lb_ip" {
  description = "Recording load balancer IP (if deployed)"
  value       = var.deploy_recording_cluster ? exoscale_nlb.recording[0].ip_address : null
}

# =============================================================================
# Database Connection Details
# =============================================================================

output "db_private_ip" {
  description = "Database server private IP"
  value       = local.db_private_ip
}

output "mysql_host" {
  description = "MySQL database host (private IP)"
  value       = local.db_private_ip
}

output "mysql_port" {
  description = "MySQL database port"
  value       = 3306
}

output "mysql_database" {
  description = "MySQL database name"
  value       = "jambones"
}

output "mysql_username" {
  description = "MySQL username"
  value       = var.mysql_username
}

output "redis_host" {
  description = "Redis hostname (runs on DB VM)"
  value       = local.db_private_ip
}

output "redis_port" {
  description = "Redis port"
  value       = 6379
}

# =============================================================================
# SSH Connection Commands
# =============================================================================

output "ssh_web_monitoring" {
  description = "SSH command for web/monitoring server"
  value       = "ssh jambonz@${exoscale_elastic_ip.web_monitoring.ip_address}"
}

output "ssh_sbc" {
  description = "SSH commands for SBC servers"
  value       = [for i, eip in exoscale_elastic_ip.sbc : "ssh jambonz@${eip.ip_address}  # SBC-${i + 1}"]
}

output "ssh_db" {
  description = "SSH command for database server (via SBC jump host)"
  value       = "ssh -J jambonz@${exoscale_elastic_ip.sbc[0].ip_address} jambonz@${local.db_private_ip}"
}

output "ssh_feature_servers" {
  description = "To get feature server IPs, run this command"
  value       = "exo compute instance list --zone ${var.zone} -O json | jq -r --arg p pool-${substr(exoscale_instance_pool.feature_server.id, 0, 5)} '.[] | select(.name | startswith($p)) | .ip_address'"
}

output "ssh_recording_servers" {
  description = "To get recording server IPs, run this command"
  value       = var.deploy_recording_cluster ? "exo compute instance list --zone ${var.zone} -O json | jq -r --arg p pool-${substr(exoscale_instance_pool.recording[0].id, 0, 5)} '.[] | select(.name | startswith($p)) | .ip_address'" : "N/A - not deployed"
}

# =============================================================================
# DNS Records Required
# =============================================================================

output "dns_records" {
  description = "DNS A records that need to be created"
  value = {
    (var.url_portal)                  = exoscale_elastic_ip.web_monitoring.ip_address
    "api.${var.url_portal}"           = exoscale_elastic_ip.web_monitoring.ip_address
    "grafana.${var.url_portal}"       = exoscale_elastic_ip.web_monitoring.ip_address
    "homer.${var.url_portal}"         = exoscale_elastic_ip.web_monitoring.ip_address
    "public-apps.${var.url_portal}"   = exoscale_elastic_ip.web_monitoring.ip_address
    "sip.${var.url_portal}"           = exoscale_elastic_ip.sbc[0].ip_address
  }
}

# =============================================================================
# Credentials
# =============================================================================

output "portal_password" {
  description = "Initial portal password (instance ID of web/monitoring server)"
  value       = exoscale_compute_instance.web_monitoring.id
  sensitive   = true
}

output "jwt_secret" {
  description = "JWT secret for API authentication"
  value       = random_password.encryption_secret.result
  sensitive   = true
}

output "mysql_password" {
  description = "MySQL database password"
  value       = local.db_password
  sensitive   = true
}
