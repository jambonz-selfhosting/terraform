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

output "sip_domain" {
  description = "SIP domain"
  value       = "sip.${var.url_portal}"
}

# =============================================================================
# Public IP
# =============================================================================

output "public_ip" {
  description = "Public IP address of the jambonz mini server"
  value       = hcloud_server.mini.ipv4_address
}

output "server_ip" {
  description = "Server IP (alias for public_ip, used by post_install.py)"
  value       = hcloud_server.mini.ipv4_address
}

# =============================================================================
# SSH Connection
# =============================================================================

output "ssh_connection" {
  description = "SSH command to connect to the instance"
  value       = "ssh jambonz@${hcloud_server.mini.ipv4_address}"
}

# =============================================================================
# DNS Records Required
# =============================================================================

output "dns_records_required" {
  description = "DNS A records that need to be created"
  value       = <<-EOT
    Create the following DNS A records (all pointing to the same IP):

    ${var.url_portal}                    → ${hcloud_server.mini.ipv4_address}
    api.${var.url_portal}                → ${hcloud_server.mini.ipv4_address}
    grafana.${var.url_portal}            → ${hcloud_server.mini.ipv4_address}
    homer.${var.url_portal}              → ${hcloud_server.mini.ipv4_address}
    sip.${var.url_portal}                → ${hcloud_server.mini.ipv4_address}
  EOT
}

# =============================================================================
# Credentials
# =============================================================================

output "portal_password" {
  description = "Initial portal password (instance ID of mini server)"
  value       = hcloud_server.mini.id
  sensitive   = true
}

output "jwt_secret" {
  description = "JWT secret for API authentication"
  value       = random_password.encryption_secret.result
  sensitive   = true
}

# =============================================================================
# Summary Output
# =============================================================================

output "deployment_summary" {
  description = "Deployment summary"
  sensitive   = true
  value       = <<-EOT
    ============================================================
    Jambonz Mini Deployment Complete! (Hetzner Cloud)
    ============================================================

    Portal URL:  http://${var.url_portal}
    Username:    admin
    Password:    ${hcloud_server.mini.id} (instance ID)

    Server IP:   ${hcloud_server.mini.ipv4_address}

    IMPORTANT: Configure DNS records (see dns_records_required output)

    SSH Access:
    - ssh jambonz@${hcloud_server.mini.ipv4_address}

    For automated DNS + TLS setup, run:
      python ../../post_install.py --email admin@example.com
    ============================================================
  EOT
}
