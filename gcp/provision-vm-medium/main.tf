# Main Terraform configuration for jambonz medium cluster on GCP

# ------------------------------------------------------------------------------
# RANDOM SECRETS
# ------------------------------------------------------------------------------

# Generate JWT/Encryption secret
resource "random_password" "encryption_secret" {
  length  = 32
  special = false
}

# Generate database password if not provided
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

locals {
  db_password = var.mysql_password != "" ? var.mysql_password : random_password.db_password.result

  # Zones to spread across: var.zones, or the region's first three.
  zones = length(var.zones) > 0 ? var.zones : slice(data.google_compute_zones.available.names, 0, 3)
}

data "google_compute_zones" "available" {
  region = var.region
}

# ------------------------------------------------------------------------------
# SECRETS
#
# Every secret the VMs need lives in Secret Manager. Startup scripts read them
# with the VM's service account, so none is written into instance metadata
# (which anyone with compute.instances.get, and any process on the VM, can read).
# ------------------------------------------------------------------------------

resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

locals {
  secret_values = {
    "mysql-password"       = local.db_password
    "encryption-secret"    = random_password.encryption_secret.result
    "redis-auth"           = google_redis_instance.jambonz.auth_string
    "apiban-key"           = var.apiban_key
    "apiban-client-secret" = var.apiban_client_secret
    "krisp-license-key"    = var.krisp_license_key
  }
  # Optional secrets are created only when set. Whether one is set is not secret.
  secret_names = toset([for k, v in local.secret_values : k
  if contains(["mysql-password", "encryption-secret", "redis-auth"], k) || nonsensitive(v != "")])
}

resource "google_secret_manager_secret" "jambonz" {
  for_each  = local.secret_names
  secret_id = "${var.name_prefix}-${each.key}"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    service     = "jambonz"
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "jambonz" {
  for_each    = local.secret_names
  secret      = google_secret_manager_secret.jambonz[each.key].id
  secret_data = local.secret_values[each.key]
}

# The VMs read named secrets only.
resource "google_secret_manager_secret_iam_member" "jambonz" {
  for_each  = local.secret_names
  secret_id = google_secret_manager_secret.jambonz[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.jambonz.email}"
}

# ------------------------------------------------------------------------------
# SERVICE ACCOUNT
# ------------------------------------------------------------------------------

resource "google_service_account" "jambonz" {
  account_id   = "${var.name_prefix}-sa"
  display_name = "jambonz Service Account"
  description  = "Service account for jambonz VMs"
}

# Least privilege. The only Compute API call the VMs make is a feature server
# deleting itself after draining at scale-in, so the service account gets a
# custom role with just that permission, limited by an IAM condition to this
# deployment's feature servers. (It previously held roles/compute.instanceAdmin.v1
# on the whole project.) Custom role IDs stay reserved for 7 days after
# deletion, hence the random suffix.
resource "random_id" "role_suffix" {
  byte_length = 3
}

resource "google_project_iam_custom_role" "self_delete" {
  role_id     = "${replace(var.name_prefix, "-", "_")}_fs_self_delete_${random_id.role_suffix.hex}"
  title       = "jambonz ${var.name_prefix} feature server self-delete"
  permissions = ["compute.instances.delete"]
}

resource "google_project_iam_member" "self_delete" {
  project = var.project_id
  role    = google_project_iam_custom_role.self_delete.id
  member  = "serviceAccount:${google_service_account.jambonz.email}"

  condition {
    title      = "${var.name_prefix} feature servers only"
    expression = "resource.type == \"compute.googleapis.com/Instance\" && resource.name.extract(\"/instances/{name}\").startsWith(\"${var.name_prefix}-fs-\")"
  }
}

# The Ops Agent writes logs and metrics.
resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.jambonz.email}"
}

resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.jambonz.email}"
}

# ------------------------------------------------------------------------------
# VPC NETWORK
# ------------------------------------------------------------------------------

resource "google_compute_network" "jambonz" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "public" {
  name                     = "${var.name_prefix}-subnet"
  ip_cidr_range            = var.public_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.jambonz.id
  private_ip_google_access = true
}

# Reserved IP range for Private Service Access (Cloud SQL, Memorystore)
resource "google_compute_global_address" "private_services" {
  name          = "${var.name_prefix}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.jambonz.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.jambonz.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}

# ------------------------------------------------------------------------------
# CLOUD ROUTER AND NAT (for instances without public IPs)
# ------------------------------------------------------------------------------

resource "google_compute_router" "jambonz" {
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = google_compute_network.jambonz.id
}

resource "google_compute_router_nat" "jambonz" {
  name                               = "${var.name_prefix}-nat"
  router                             = google_compute_router.jambonz.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = false
    filter = "ERRORS_ONLY"
  }
}

# ------------------------------------------------------------------------------
# FIREWALL RULES
# ------------------------------------------------------------------------------

# SSH access
resource "google_compute_firewall" "ssh" {
  name    = "${var.name_prefix}-allow-ssh"
  network = google_compute_network.jambonz.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_cidr
  target_tags   = ["jambonz"]
}

# Inside the VPC each role accepts only the ports it serves. GCP denies any
# ingress no rule allows, so there is no allow-all internal rule: a compromised
# VM cannot reach arbitrary ports on the others. Port lists follow the AWS large
# template's security groups.
locals {
  internal_rules = {
    feature-server = { tag = "jambonz-fs", tcp = ["3000-3009", "5060"], udp = ["5060", "16000-32000"] }
    # Web and monitoring share one host: the portal, API and webapp, plus
    # Grafana, InfluxDB, Homer and Jaeger.
    web-monitoring = { tag = "jambonz-web", tcp = concat(["3000", "3010", "8086", "8088", "9080", "16686", "14268-14269"], var.deploy_recording_cluster ? [] : ["3017"]), udp = ["9060"] }
    # SIP and RTP share one host.
    sbc       = { tag = "jambonz-sbc", tcp = ["3000-3009", "5060", "8080", "9090"], udp = ["5060", "22222-22223", "22224-22233", "40000-60000"] }
    recording = { tag = "jambonz-recording", tcp = ["3000"], udp = [] }
  }
}

resource "google_compute_firewall" "internal" {
  for_each = local.internal_rules
  name     = "${var.name_prefix}-allow-internal-${each.key}"
  network  = google_compute_network.jambonz.name

  dynamic "allow" {
    for_each = length(each.value.tcp) > 0 ? [1] : []
    content {
      protocol = "tcp"
      ports    = each.value.tcp
    }
  }

  dynamic "allow" {
    for_each = length(each.value.udp) > 0 ? [1] : []
    content {
      protocol = "udp"
      ports    = each.value.udp
    }
  }

  source_ranges = [var.vpc_cidr]
  target_tags   = [each.value.tag]
}

resource "google_compute_firewall" "internal_icmp" {
  name    = "${var.name_prefix}-allow-internal-icmp"
  network = google_compute_network.jambonz.name

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.vpc_cidr]
  target_tags   = ["jambonz"]
}

# Web/Monitoring HTTP/HTTPS. The API (3000) and Grafana are reached through
# nginx (api.<portal>, grafana.<portal>), so no app port is public.
resource "google_compute_firewall" "web_monitoring" {
  name    = "${var.name_prefix}-allow-web"
  network = google_compute_network.jambonz.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = var.allowed_http_cidr
  target_tags   = ["jambonz-web"]
}

# SBC SIP/RTP traffic
resource "google_compute_firewall" "sbc" {
  name    = "${var.name_prefix}-allow-sbc"
  network = google_compute_network.jambonz.name

  allow {
    protocol = "tcp"
    ports    = ["5060", "5061", "8443"]
  }

  allow {
    protocol = "udp"
    ports    = ["5060", "40000-60000"]
  }

  source_ranges = var.allowed_sbc_cidr
  target_tags   = ["jambonz-sbc"]
}

# Health check firewall rule (GCP health check ranges)
resource "google_compute_firewall" "health_check" {
  name    = "${var.name_prefix}-allow-health-check"
  network = google_compute_network.jambonz.name

  allow {
    protocol = "tcp"
    ports    = ["3000", "80"]
  }

  # GCP health check IP ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["jambonz"]
}
