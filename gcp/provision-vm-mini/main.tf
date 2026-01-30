# Main Terraform configuration for jambonz mini (single VM) on GCP
# All-in-one deployment with local MySQL, Redis, and monitoring

# ------------------------------------------------------------------------------
# RANDOM SECRETS
# ------------------------------------------------------------------------------

# Generate JWT/Encryption secret
resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

# Generate database password
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
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

# HTTP/HTTPS (web portal, API, Grafana, Homer)
resource "google_compute_firewall" "web" {
  name    = "${var.name_prefix}-allow-web"
  network = google_compute_network.jambonz.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "3000", "3010", "9080", "16686"]
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
