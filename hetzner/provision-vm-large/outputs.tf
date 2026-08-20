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
# Public IPs
# =============================================================================

output "monitoring_public_ip" {
  description = "Monitoring server public IP"
  value       = hcloud_server.monitoring.ipv4_address
}

output "web_public_ip" {
  description = "Web server public IP"
  value       = hcloud_server.web.ipv4_address
}

output "sip_public_ips" {
  description = "SIP server public IPs"
  value       = [for s in hcloud_server.sip : s.ipv4_address]
}

output "rtp_public_ips" {
  description = "RTP server public IPs"
  value       = [for s in hcloud_server.rtp : s.ipv4_address]
}

output "feature_server_public_ips" {
  description = "Feature server public IPs"
  value       = [for s in hcloud_server.feature_server : s.ipv4_address]
}

output "recording_server_public_ips" {
  description = "Recording server public IPs (if deployed)"
  value       = var.deploy_recording_cluster ? [for s in hcloud_server.recording : s.ipv4_address] : []
}

# =============================================================================
# Private IPs
# =============================================================================

output "db_private_ip" {
  description = "Database server private IP"
  value       = local.db_private_ip
}

output "monitoring_private_ip" {
  description = "Monitoring server private IP"
  value       = local.monitoring_private_ip
}

output "recording_lb_ip" {
  description = "Recording load balancer IP (if deployed)"
  value       = var.deploy_recording_cluster ? hcloud_load_balancer.recording[0].ipv4 : null
}

# =============================================================================
# Database Connection Details
# =============================================================================

output "mysql_host" {
  description = "MySQL database host (private IP)"
  value       = local.db_private_ip
  sensitive   = true
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

output "mysql_password" {
  description = "MySQL database password"
  value       = local.db_password
  sensitive   = true
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

output "ssh_monitoring" {
  description = "SSH command for monitoring server"
  value       = "ssh jambonz@${hcloud_server.monitoring.ipv4_address}"
}

output "ssh_web" {
  description = "SSH command for web server"
  value       = "ssh jambonz@${hcloud_server.web.ipv4_address}"
}

output "ssh_db" {
  description = "SSH command for database server (via SIP jump host)"
  value       = "ssh -J jambonz@${hcloud_server.sip[0].ipv4_address} jambonz@${local.db_private_ip}"
}

output "ssh_sip" {
  description = "SSH commands for SIP servers"
  value       = [for i, s in hcloud_server.sip : "ssh jambonz@${s.ipv4_address}  # SIP-${i + 1}"]
}

output "ssh_rtp" {
  description = "SSH commands for RTP servers"
  value       = [for i, s in hcloud_server.rtp : "ssh jambonz@${s.ipv4_address}  # RTP-${i + 1}"]
}

output "ssh_feature_servers" {
  description = "SSH commands for feature servers"
  value       = [for i, s in hcloud_server.feature_server : "ssh jambonz@${s.ipv4_address}  # FS-${i + 1}"]
}

output "ssh_recording_servers" {
  description = "SSH commands for recording servers (if deployed)"
  value       = var.deploy_recording_cluster ? [for i, s in hcloud_server.recording : "ssh jambonz@${s.ipv4_address}  # REC-${i + 1}"] : []
}

output "ssh_config_snippet" {
  description = "SSH config snippet for ~/.ssh/config"
  value       = <<-EOT
    # Add this to ~/.ssh/config for easier access

    # Monitoring Server
    Host jambonz-monitoring
      HostName ${hcloud_server.monitoring.ipv4_address}
      User jambonz

    # Web Server
    Host jambonz-web
      HostName ${hcloud_server.web.ipv4_address}
      User jambonz

    # Database Server (via SIP jump)
    Host jambonz-db
      HostName ${local.db_private_ip}
      User jambonz
      ProxyJump jambonz-sip-1

    # SIP Servers
    %{for i, s in hcloud_server.sip~}
    Host jambonz-sip-${i + 1}
      HostName ${s.ipv4_address}
      User jambonz
    %{endfor~}

    # RTP Servers
    %{for i, s in hcloud_server.rtp~}
    Host jambonz-rtp-${i + 1}
      HostName ${s.ipv4_address}
      User jambonz
    %{endfor~}

    # Feature Servers
    %{for i, s in hcloud_server.feature_server~}
    Host jambonz-fs-${i + 1}
      HostName ${s.ipv4_address}
      User jambonz
    %{endfor~}

    # Recording Servers
    %{if var.deploy_recording_cluster~}
    %{for i, s in hcloud_server.recording~}
    Host jambonz-rec-${i + 1}
      HostName ${s.ipv4_address}
      User jambonz
    %{endfor~}
    %{endif~}
  EOT
}

# =============================================================================
# DNS Records Required
# =============================================================================

output "dns_records_required" {
  description = "DNS A records that need to be created"
  value       = <<-EOT
    Create the following DNS A records:

    ${var.url_portal}                    → ${hcloud_server.web.ipv4_address}
    api.${var.url_portal}                → ${hcloud_server.web.ipv4_address}
    grafana.${var.url_portal}            → ${hcloud_server.web.ipv4_address}
    homer.${var.url_portal}              → ${hcloud_server.web.ipv4_address}
    public-apps.${var.url_portal}        → ${hcloud_server.web.ipv4_address}
    sip.${var.url_portal}                → ${hcloud_server.sip[0].ipv4_address}%{if var.sip_count > 1} (primary SIP)%{endif}
    %{if var.sip_count > 1~}
    %{for i in range(1, var.sip_count)~}
    sip-${i + 1}.${var.url_portal}       → ${hcloud_server.sip[i].ipv4_address}
    %{endfor~}
    %{endif~}
  EOT
}

# =============================================================================
# Credentials and Instance Info
# =============================================================================

output "portal_password" {
  description = "Initial portal password (instance ID of web server)"
  value       = hcloud_server.web.id
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
    Jambonz Large Cluster Deployment Complete! (Hetzner Cloud)
    ============================================================

    Portal URL:  http://${var.url_portal}
    Username:    admin
    Password:    ${hcloud_server.web.id} (instance ID)

    Monitoring:     ${hcloud_server.monitoring.ipv4_address}
    Web:            ${hcloud_server.web.ipv4_address}
    Database:       ${local.db_private_ip} (private, MySQL + Redis on dedicated VM)
    SIP Servers:    ${join(", ", [for s in hcloud_server.sip : s.ipv4_address])}
    RTP Servers:    ${join(", ", [for s in hcloud_server.rtp : s.ipv4_address])}

    Feature Servers: ${join(", ", [for s in hcloud_server.feature_server : s.ipv4_address])}
    Recording Cluster: ${var.deploy_recording_cluster ? join(", ", [for s in hcloud_server.recording : s.ipv4_address]) : "Not deployed"}

    MySQL:  ${local.db_private_ip}:3306 (dedicated DB VM)
    Redis:  ${local.db_private_ip}:6379 (on dedicated DB VM)

    IMPORTANT: Configure DNS records (see dns_records_required output)

    SSH Access:
    - Monitoring: ssh jambonz@${hcloud_server.monitoring.ipv4_address}
    - Web: ssh jambonz@${hcloud_server.web.ipv4_address}
    - SIP (jump host): ssh jambonz@${hcloud_server.sip[0].ipv4_address}
    - Database: ssh -J jambonz@${hcloud_server.sip[0].ipv4_address} jambonz@${local.db_private_ip}
    - RTP Servers: see ssh_rtp output
    - Feature Servers: see ssh_feature_servers output
    - Recording Servers: see ssh_recording_servers output

    For detailed SSH configuration, run:
      terraform output ssh_config_snippet
    ============================================================
  EOT
}
