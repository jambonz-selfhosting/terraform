# =============================================================================
# Fetch Exoscale Official IP Ranges
# =============================================================================

data "http" "exoscale_ip_ranges" {
  url = "https://exoscale-prefixes.sos-ch-dk-2.exo.io/exoscale_prefixes.json"
}

locals {
  # Parse Exoscale IP ranges for our zone
  all_prefixes = jsondecode(data.http.exoscale_ip_ranges.response_body).prefixes
  zone_ipv4_ranges = [
    for prefix in local.all_prefixes :
    prefix["IPv4Prefix"]
    if prefix.zone == var.zone && lookup(prefix, "IPv4Prefix", null) != null
  ]

  # Collect all public IPs that need DBaaS access
  dbaas_allowed_ips = concat(
    # Specific Elastic IPs for static servers
    ["${exoscale_elastic_ip.web_monitoring.ip_address}/32"],
    [for eip in exoscale_elastic_ip.sbc : "${eip.ip_address}/32"],

    # Zone-wide CIDR ranges for instance pool members
    local.zone_ipv4_ranges
  )
}

# =============================================================================
# Exoscale DBaaS MySQL
# =============================================================================

resource "exoscale_dbaas" "mysql" {
  zone = var.zone
  name = "${var.name_prefix}-mysql"
  type = "mysql"
  plan = var.mysql_plan

  maintenance_dow  = "sunday"
  maintenance_time = "03:00:00"

  termination_protection = false

  mysql {
    version        = "8"
    admin_username = var.mysql_username
    admin_password = local.db_password
    # Allow connections from:
    # - Elastic IPs for web/monitoring and SBC servers (predictable, specific /32)
    # - Zone-wide CIDR ranges for instance pool members (ephemeral public IPs)
    ip_filter = local.dbaas_allowed_ips

    # Exoscale DBaaS defaults to ANSI_QUOTES sql_mode which treats double quotes
    # as identifier quotes, breaking standard SQL like WHERE name = "admin".
    # Set TRADITIONAL to use standard MySQL quoting behavior.
    mysql_settings = jsonencode({
      sql_mode = "TRADITIONAL"
    })
  }
}

# =============================================================================
# Database Connection Information
# =============================================================================

# Get MySQL connection URI
data "exoscale_database_uri" "mysql" {
  zone = var.zone
  name = exoscale_dbaas.mysql.name
  type = "mysql"
}

# =============================================================================
# Redis runs locally on the web-monitoring VM (not DBaaS)
# Exoscale DBaaS Valkey requires TLS which jambonz apps don't support.
# SBC and feature servers connect to Redis on the web-monitoring private IP.
# =============================================================================
