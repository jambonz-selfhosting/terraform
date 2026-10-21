# Main Terraform configuration for jambonz mini (single VM) on GCP
# All-in-one deployment with local MySQL, Redis, and monitoring

# ------------------------------------------------------------------------------
# SECRETS
#
# The database password and the JWT/encryption secret are generated on the VM at
# first boot (see the startup script). Nothing outside the VM uses them, so they
# never appear in instance metadata or in terraform state.
#
# Secrets you supply (apiban, Krisp) go in Secret Manager, created only when at
# least one is set, and the VM reads them at boot with its service account.
# ------------------------------------------------------------------------------

locals {
  supplied_secret_values = {
    "apiban-key"           = var.apiban_key
    "apiban-client-secret" = var.apiban_client_secret
    "krisp-license-key"    = var.krisp_license_key
  }
  # Whether each secret is set is not itself secret.
  supplied_secret_names = toset([for k, v in local.supplied_secret_values : k if nonsensitive(v != "")])
}

resource "google_project_service" "secretmanager" {
  count              = length(local.supplied_secret_names) > 0 ? 1 : 0
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "jambonz" {
  for_each  = local.supplied_secret_names
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
  for_each    = local.supplied_secret_names
  secret      = google_secret_manager_secret.jambonz[each.key].id
  secret_data = local.supplied_secret_values[each.key]
}

resource "google_secret_manager_secret_iam_member" "jambonz" {
  for_each  = local.supplied_secret_names
  secret_id = google_secret_manager_secret.jambonz[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.jambonz.email}"
}

# ------------------------------------------------------------------------------
# SERVICE ACCOUNT
#
# Least privilege: the VM writes its logs and metrics (Ops Agent) and reads the
# secrets above, nothing else.
# ------------------------------------------------------------------------------

resource "google_service_account" "jambonz" {
  account_id   = "${var.name_prefix}-sa"
  display_name = "jambonz Service Account"
  description  = "Service account for the jambonz mini VM"
}

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

# ------------------------------------------------------------------------------
# CLOUD ROUTER AND NAT (for outbound internet access)
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

# No internal rule: the mini is the only VM in the network, and GCP denies any
# ingress no rule allows.

# HTTP/HTTPS. The portal, API and Grafana are all served through nginx
# (<portal>, api.<portal>, grafana.<portal>), so no app port is public.
resource "google_compute_firewall" "web" {
  name    = "${var.name_prefix}-allow-web"
  network = google_compute_network.jambonz.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = var.allowed_http_cidr
  target_tags   = ["jambonz"]
}

# SIP/RTP traffic
resource "google_compute_firewall" "sip_rtp" {
  name    = "${var.name_prefix}-allow-sip-rtp"
  network = google_compute_network.jambonz.name

  allow {
    protocol = "tcp"
    ports    = ["5060", "5061", "8443"]
  }

  allow {
    protocol = "udp"
    ports    = ["5060", "40000-60000"]
  }

  source_ranges = var.allowed_sip_cidr
  target_tags   = ["jambonz"]
}
