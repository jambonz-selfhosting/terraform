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
# Public IP
# =============================================================================

output "public_ip" {
  description = "Public IP address of the jambonz mini server"
  value       = exoscale_compute_instance.mini.public_ip_address
}

output "server_ip" {
  description = "Server IP (alias for public_ip, used by post_install.py)"
  value       = exoscale_compute_instance.mini.public_ip_address
}

# =============================================================================
# SSH Connection
# =============================================================================

output "ssh_connection" {
  description = "SSH command to connect to the instance"
  value       = "ssh jambonz@${exoscale_compute_instance.mini.public_ip_address}"
}

# =============================================================================
# DNS Records Required
# =============================================================================

output "dns_records_required" {
  description = "DNS A records that need to be created"
  value       = <<-EOT
    Create the following DNS A records (all pointing to the same IP):

    ${var.url_portal}                    → ${exoscale_compute_instance.mini.public_ip_address}
    api.${var.url_portal}                → ${exoscale_compute_instance.mini.public_ip_address}
    grafana.${var.url_portal}            → ${exoscale_compute_instance.mini.public_ip_address}
    homer.${var.url_portal}              → ${exoscale_compute_instance.mini.public_ip_address}
    sip.${var.url_portal}                → ${exoscale_compute_instance.mini.public_ip_address}
  EOT
}

# =============================================================================
# Credentials
# =============================================================================

output "portal_password" {
  description = "Initial portal password (instance ID of mini server)"
  value       = exoscale_compute_instance.mini.id
  sensitive   = true
}

output "jwt_secret" {
  description = "JWT secret for API authentication"
  value       = random_password.encryption_secret.result
  sensitive   = true
}

# =============================================================================
# Instance Info
# =============================================================================

output "instance_id" {
  description = "Exoscale compute instance ID"
  value       = exoscale_compute_instance.mini.id
}

output "instance_name" {
  description = "Exoscale compute instance name"
  value       = exoscale_compute_instance.mini.name
}

# =============================================================================
# Summary Output
# =============================================================================

output "deployment_summary" {
  description = "Deployment summary"
  sensitive   = true
  value       = <<-EOT
    ============================================================
    Jambonz Mini Deployment Complete! (Exoscale)
    ============================================================

    Portal URL:  http://${var.url_portal}
    Username:    admin
    Password:    ${exoscale_compute_instance.mini.id} (instance ID)

    Server IP:   ${exoscale_compute_instance.mini.public_ip_address}

    IMPORTANT: Configure DNS records (see dns_records_required output)

    SSH Access:
    - ssh jambonz@${exoscale_compute_instance.mini.public_ip_address}

    For automated DNS + TLS setup, run:
      python ../../post_install.py --email admin@example.com
    ============================================================
  EOT
}
