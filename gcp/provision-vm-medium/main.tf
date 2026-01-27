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
}

# ------------------------------------------------------------------------------
# SERVICE ACCOUNT
# ------------------------------------------------------------------------------

resource "google_service_account" "jambonz" {
  account_id   = "${var.name_prefix}-sa"
  display_name = "jambonz Service Account"
  description  = "Service account for jambonz VMs"
}

# Grant Compute Instance Admin for self-deletion during graceful scale-in
resource "google_project_iam_member" "compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
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

# Internal VPC communication
resource "google_compute_firewall" "internal" {
  name    = "${var.name_prefix}-allow-internal"
  network = google_compute_network.jambonz.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.vpc_cidr]
  target_tags   = ["jambonz"]
}

# Web/Monitoring HTTP/HTTPS
resource "google_compute_firewall" "web_monitoring" {
  name    = "${var.name_prefix}-allow-web"
  network = google_compute_network.jambonz.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "3000"]
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

# Feature Server ports (internal only, but need health checks)
resource "google_compute_firewall" "feature_server" {
  name    = "${var.name_prefix}-allow-fs"
  network = google_compute_network.jambonz.name

  allow {
    protocol = "tcp"
    ports    = ["3000-3009", "5060"]
  }

  allow {
    protocol = "udp"
    ports    = ["5060", "25000-40000"]
  }

  source_ranges = [var.vpc_cidr]
  target_tags   = ["jambonz-fs"]
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

# Recording Server ports
resource "google_compute_firewall" "recording" {
  count   = var.deploy_recording_cluster ? 1 : 0
  name    = "${var.name_prefix}-allow-recording"
  network = google_compute_network.jambonz.name

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = [var.vpc_cidr]
  target_tags   = ["jambonz-recording"]
}
