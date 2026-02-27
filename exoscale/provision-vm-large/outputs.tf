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
# Public IPs
# =============================================================================

output "web_public_ip" {
  description = "Web server public IP"
  value       = exoscale_elastic_ip.web.ip_address
}

output "monitoring_public_ip" {
  description = "Monitoring server public IP"
  value       = exoscale_elastic_ip.monitoring.ip_address
}

output "sip_public_ips" {
  description = "SIP server public IPs"
  value       = [for eip in exoscale_elastic_ip.sip : eip.ip_address]
}

output "rtp_public_ips" {
  description = "RTP server public IPs"
  value       = [for eip in exoscale_elastic_ip.rtp : eip.ip_address]
}

# =============================================================================
# Private IPs
# =============================================================================

output "monitoring_private_ip" {
  description = "Monitoring server private IP (Redis runs here)"
  value       = local.monitoring_private_ip
}

output "rtp_private_ips" {
  description = "RTP server private IPs"
  value       = [for rtp in exoscale_compute_instance.rtp : one(rtp.network_interface).ip_address]
}

# =============================================================================
# Instance Pool IDs
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
# DBaaS Access Information
# =============================================================================

output "dbaas_ip_filter_configured" {
  description = "IP addresses/CIDRs whitelisted for DBaaS access"
  value       = local.dbaas_allowed_ips
}

output "exoscale_zone_ip_ranges" {
  description = "Exoscale public IP ranges whitelisted for this zone"
  value       = local.zone_ipv4_ranges
}

output "instance_pool_public_ip_notice" {
  description = "Instructions for managing instance pool public IPs"
  value       = <<-EOT
    Instance Pool Public IPs:
    - Feature servers: Each member gets native public IPv4 (ephemeral, free)
    - Recording servers: Each member gets native public IPv4 (ephemeral, free)

    These IPs fall within Exoscale's official IP ranges for ${var.zone}:
    ${join(", ", local.zone_ipv4_ranges)}

    To view actual public IPs:
    exo compute instance list --zone ${var.zone} --output-format json | \
      jq '.[] | select(.labels.cluster=="${var.name_prefix}") | {name, role: .labels.role, public_ip}'
  EOT
}

# =============================================================================
# Database Connection Details
# =============================================================================

output "mysql_host" {
  description = "MySQL database hostname"
  value       = data.exoscale_database_uri.mysql.host
  sensitive   = true
}

output "mysql_port" {
  description = "MySQL database port"
  value       = data.exoscale_database_uri.mysql.port
}

output "mysql_database" {
  description = "MySQL database name"
  value       = data.exoscale_database_uri.mysql.db_name
}

output "mysql_username" {
  description = "MySQL username"
  value       = data.exoscale_database_uri.mysql.username
}

output "redis_host" {
  description = "Redis hostname (local on monitoring VM)"
  value       = local.monitoring_private_ip
}

output "redis_port" {
  description = "Redis port"
  value       = 6379
}

# =============================================================================
# SSH Connection Commands
# =============================================================================

output "ssh_web" {
  description = "SSH command for web server"
  value       = "ssh jambonz@${exoscale_elastic_ip.web.ip_address}"
}

output "ssh_monitoring" {
  description = "SSH command for monitoring server"
  value       = "ssh jambonz@${exoscale_elastic_ip.monitoring.ip_address}"
}

output "ssh_sip" {
  description = "SSH commands for SIP servers"
  value       = [for i, eip in exoscale_elastic_ip.sip : "ssh jambonz@${eip.ip_address}  # SIP-${i + 1}"]
}

output "ssh_rtp" {
  description = "SSH commands for RTP servers"
  value       = [for i, eip in exoscale_elastic_ip.rtp : "ssh jambonz@${eip.ip_address}  # RTP-${i + 1}"]
}

output "ssh_feature_server_via_jump" {
  description = "SSH to feature servers via SIP jump server"
  value       = "ssh -J jambonz@${exoscale_elastic_ip.sip[0].ip_address} jambonz@<FEATURE-SERVER-PRIVATE-IP>"
}

output "ssh_recording_via_jump" {
  description = "SSH to recording servers via SIP jump server (if deployed)"
  value       = var.deploy_recording_cluster ? "ssh -J jambonz@${exoscale_elastic_ip.sip[0].ip_address} jambonz@<RECORDING-SERVER-PRIVATE-IP>" : "N/A - Recording cluster not deployed"
}

output "ssh_config_snippet" {
  description = "SSH config snippet for ~/.ssh/config"
  value       = <<-EOT
    # Add this to ~/.ssh/config for easier access

    # Web Server
    Host jambonz-web
      HostName ${exoscale_elastic_ip.web.ip_address}
      User jambonz

    # Monitoring Server
    Host jambonz-monitoring
      HostName ${exoscale_elastic_ip.monitoring.ip_address}
      User jambonz

    # SIP Servers
    %{for i, eip in exoscale_elastic_ip.sip~}
    Host jambonz-sip-${i + 1}
      HostName ${eip.ip_address}
      User jambonz
    %{endfor~}

    # RTP Servers
    %{for i, eip in exoscale_elastic_ip.rtp~}
    Host jambonz-rtp-${i + 1}
      HostName ${eip.ip_address}
      User jambonz
    %{endfor~}

    # Feature Servers (via SIP jump)
    Host jambonz-fs-*
      User jambonz
      ProxyJump jambonz-sip-1

    # Recording Servers (via SIP jump)
    %{if var.deploy_recording_cluster~}
    Host jambonz-rec-*
      User jambonz
      ProxyJump jambonz-sip-1
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

    ${var.url_portal}                    → ${exoscale_elastic_ip.web.ip_address}
    api.${var.url_portal}                → ${exoscale_elastic_ip.web.ip_address}
    grafana.${var.url_portal}            → ${exoscale_elastic_ip.web.ip_address}
    homer.${var.url_portal}              → ${exoscale_elastic_ip.web.ip_address}
    public-apps.${var.url_portal}        → ${exoscale_elastic_ip.web.ip_address}
    sip.${var.url_portal}                → ${exoscale_elastic_ip.sip[0].ip_address}%{if var.sip_count > 1} (primary SIP)%{endif}
    %{if var.sip_count > 1~}
    %{for i in range(1, var.sip_count)~}
    sip-${i + 1}.${var.url_portal}       → ${exoscale_elastic_ip.sip[i].ip_address}
    %{endfor~}
    %{endif~}
  EOT
}

# =============================================================================
# Credentials and Instance Info
# =============================================================================

output "portal_password" {
  description = "Initial portal password (instance ID of web server)"
  value       = exoscale_compute_instance.web.id
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

# =============================================================================
# Instance Pool Management Commands
# =============================================================================

output "exoscale_cli_commands" {
  description = "Useful Exoscale CLI commands for managing the deployment"
  value       = <<-EOT
    # List all compute instances
    exo compute instance list --zone ${var.zone}

    # List feature server pool instances
    exo compute instance-pool show ${exoscale_instance_pool.feature_server.id} --zone ${var.zone}

    # Scale feature server pool
    exo compute instance-pool scale ${exoscale_instance_pool.feature_server.id} --size <NEW-SIZE> --zone ${var.zone}

    %{if var.deploy_recording_cluster~}
    # List recording server pool instances
    exo compute instance-pool show ${exoscale_instance_pool.recording[0].id} --zone ${var.zone}

    # Scale recording server pool
    exo compute instance-pool scale ${exoscale_instance_pool.recording[0].id} --size <NEW-SIZE> --zone ${var.zone}
    %{endif~}

    # Get private IPs of pool instances
    exo compute instance list --zone ${var.zone} --output-format json | jq '.[] | select(.labels.cluster=="${var.name_prefix}") | {name: .name, role: .labels.role}'
  EOT
}

# =============================================================================
# Summary Output
# =============================================================================

output "deployment_summary" {
  description = "Deployment summary"
  sensitive   = true
  value       = <<-EOT
    ============================================================
    Jambonz Large Cluster Deployment Complete!
    ============================================================

    Portal URL:  http://${var.url_portal}
    Username:    admin
    Password:    ${exoscale_compute_instance.web.id} (instance ID)

    Web Server:        ${exoscale_elastic_ip.web.ip_address}
    Monitoring Server: ${exoscale_elastic_ip.monitoring.ip_address}
    SIP Servers:       ${join(", ", [for eip in exoscale_elastic_ip.sip : eip.ip_address])}
    RTP Servers:       ${join(", ", [for eip in exoscale_elastic_ip.rtp : eip.ip_address])}

    Feature Server Pool: ${var.feature_server_count} instance(s)
    Recording Cluster:   ${var.deploy_recording_cluster ? "${var.recording_server_count} instance(s)" : "Not deployed"}

    MySQL:  ${data.exoscale_database_uri.mysql.uri}
    Redis:  ${local.monitoring_private_ip}:6379 (local on monitoring VM)

    IMPORTANT: Configure DNS records (see dns_records_required output)

    SSH Access:
    - Web:        ssh jambonz@${exoscale_elastic_ip.web.ip_address}
    - Monitoring: ssh jambonz@${exoscale_elastic_ip.monitoring.ip_address}
    - SIP:        ${join(", ", [for eip in exoscale_elastic_ip.sip : "ssh jambonz@${eip.ip_address}"])}
    - RTP:        ${join(", ", [for eip in exoscale_elastic_ip.rtp : "ssh jambonz@${eip.ip_address}"])}
    - Feature/Recording: Use SIP as jump server (see ssh_config_snippet output)

    For detailed SSH configuration, run:
      terraform output ssh_config_snippet

    For Exoscale CLI commands, run:
      terraform output exoscale_cli_commands
    ============================================================
  EOT
}
