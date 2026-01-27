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

    # MySQL settings - commented out due to Exoscale API validation errors
    # Use exo dbaas type show mysql --settings=mysql to see available options
    # mysql_settings = jsonencode({
    #   max_connections = 300
    #   sql_mode        = "TRADITIONAL"
    # })
  }
}

# =============================================================================
# Exoscale DBaaS Valkey (Redis-compatible)
# =============================================================================

resource "exoscale_dbaas" "valkey" {
  zone = var.zone
  name = "${var.name_prefix}-valkey"
  type = "valkey"
  plan = var.valkey_plan

  maintenance_dow  = "sunday"
  maintenance_time = "04:00:00"

  termination_protection = false

  valkey {
    # Allow connections from:
    # - Elastic IPs for web/monitoring and SBC servers (predictable, specific /32)
    # - Zone-wide CIDR ranges for instance pool members (ephemeral public IPs)
    ip_filter = local.dbaas_allowed_ips

    # Valkey settings - commented out, can be configured after deployment
    # Use exo dbaas type show valkey --settings=valkey to see available options
    # valkey_settings = jsonencode({
    #   valkey_maxmemory_policy = "allkeys-lru"
    #   valkey_timeout          = 300
    # })
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

# Get Valkey connection URI
data "exoscale_database_uri" "valkey" {
  zone = var.zone
  name = exoscale_dbaas.valkey.name
  type = "valkey"
}
