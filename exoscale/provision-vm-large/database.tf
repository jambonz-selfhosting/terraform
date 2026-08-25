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
    ["${exoscale_elastic_ip.web.ip_address}/32"],
    ["${exoscale_elastic_ip.monitoring.ip_address}/32"],
    [for eip in exoscale_elastic_ip.sip : "${eip.ip_address}/32"],
    # RTP hosts are deliberately absent: cloud-init-rtp.yaml has no database
    # configuration at all (rtpengine and its sidecar need redis, not MySQL), so
    # they never used this. The zone-wide ranges below would cover them anyway.

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

  mysql = {
    # Exoscale retires DBaaS engine versions: "8" reached end of availability
    # and is now REJECTED at create time --
    #   invalid request: Service 'mysql' version '8' has reached end of
    #   availability and cannot be created
    # which made medium/large undeployable for everyone, not just new
    # releases. Check `exo dbaas type show mysql` for Available Versions.
    version = "8.4"

    # Must be set explicitly. Left unset, creating works but every later apply
    # that touches this resource fails:
    #
    #   Error: Validation error
    #     Unable to parse backup schedule, got error: invalid value "" for
    #     backup schedule, expecting HH:MM
    #
    # because the provider (exoscale 0.68.0) sends an empty string on update
    # where it omitted the field on create. That makes the module single-shot in
    # the same way a missing oidc_issuer_enabled does on AKS: any second apply
    # -- scaling a pool, a cloud-init change, an ip_filter change -- dies here,
    # after the instances have already been replaced.
    backup_schedule = "01:00"

    admin_username = var.mysql_username
    admin_password = local.db_password
    ip_filter      = local.dbaas_allowed_ips
    # Exoscale DBaaS defaults to ANSI_QUOTES sql_mode which treats double quotes
    # as identifier quotes, breaking standard SQL. Set TRADITIONAL for standard behavior.
    mysql_settings = jsonencode({
      sql_mode = "TRADITIONAL"
    })
  }

  # The exoscale provider (0.68.0) cannot update this resource in place. It
  # fails two different ways, and both leave the deployment half-built because
  # the instances are replaced before the error:
  #
  #   Error: Validation error
  #     Unable to parse backup schedule ... invalid value "" ... expecting HH:MM
  #
  # and, once backup_schedule is set explicitly:
  #
  #   Error: Provider produced inconsistent result after apply
  #     .mysql: inconsistent values for sensitive attribute
  #     This is a bug in the provider ...
  #
  # The block also shows a perpetual diff, so EVERY apply touches it -- meaning
  # every apply after the first one fails, however unrelated the actual change.
  # Ignoring it here is what makes the module re-appliable at all.
  #
  # The cost: changes to ip_filter, plan or mysql_settings are no longer picked
  # up by an apply. Change them with `exo dbaas update`, or taint and recreate.
  lifecycle {
    ignore_changes = [mysql]
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
# Redis runs locally on the monitoring VM (not DBaaS)
# Exoscale DBaaS Valkey requires TLS which jambonz apps don't support.
# All other servers connect to Redis on the monitoring VM's private IP.
# =============================================================================
