# VPC Network
resource "google_compute_network" "main" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

# Subnets for different node pools
resource "google_compute_subnetwork" "system" {
  name          = "system-subnet"
  ip_cidr_range = var.system_subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

resource "google_compute_subnetwork" "sip" {
  name          = "sip-subnet"
  ip_cidr_range = var.sip_subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
}

resource "google_compute_subnetwork" "rtp" {
  name          = "rtp-subnet"
  ip_cidr_range = var.rtp_subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
}

# Cloud Router for NAT
resource "google_compute_router" "router" {
  name    = "voip-router"
  region  = var.region
  network = google_compute_network.main.id
}

# Cloud NAT for private nodes to access internet
resource "google_compute_router_nat" "nat" {
  name                               = "voip-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall rules for VoIP traffic and LoadBalancer services
# Note: VoIP requires public internet access - SIP/RTP traffic originates from carriers,
# SIP trunks, and endpoints worldwide with unpredictable source IPs. Restricting
# source addresses would break VoIP functionality.

# Firewall rules for System nodes - HTTP/HTTPS for LoadBalancer services
# tfsec:ignore:google-compute-no-public-ingress - Required for LoadBalancer services
resource "google_compute_firewall" "system_http" {
  name    = "allow-system-http"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["system-nodes"]
}

# tfsec:ignore:google-compute-no-public-ingress - Required for LoadBalancer services
resource "google_compute_firewall" "system_https" {
  name    = "allow-system-https"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["system-nodes"]
}

# Firewall rule for SIP nodes (UDP 5060)
# tfsec:ignore:google-compute-no-public-ingress - Required for VoIP, traffic comes from anywhere
resource "google_compute_firewall" "sip_udp" {
  name    = "allow-sip-udp"
  network = google_compute_network.main.name

  allow {
    protocol = "udp"
    ports    = ["5060"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["sip-nodes"]
}

# Firewall rule for SIP nodes (TCP 5060)
# tfsec:ignore:google-compute-no-public-ingress - Required for VoIP, traffic comes from anywhere
resource "google_compute_firewall" "sip_tcp" {
  name    = "allow-sip-tcp"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["5060"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["sip-nodes"]
}

# Firewall rule for SIP TLS (TCP 5061)
# tfsec:ignore:google-compute-no-public-ingress - Required for VoIP, traffic comes from anywhere
resource "google_compute_firewall" "sip_tls" {
  name    = "allow-sip-tls"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["5061"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["sip-nodes"]
}

# Firewall rule for sip over websockets (TCP 8443)
# tfsec:ignore:google-compute-no-public-ingress - Required for VoIP, traffic comes from anywhere
resource "google_compute_firewall" "sip_wss" {
  name    = "allow-sip-wss"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["8443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["sip-nodes"]
}

# Firewall rule for RTP nodes (UDP 40000-60000)
# tfsec:ignore:google-compute-no-public-ingress - Required for VoIP, media comes from anywhere
resource "google_compute_firewall" "rtp" {
  name    = "allow-rtp-udp"
  network = google_compute_network.main.name

  allow {
    protocol = "udp"
    ports    = ["40000-60000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["rtp-nodes"]
}

# GKE Cluster
resource "google_container_cluster" "main" {
  name     = var.cluster_name
  location = var.region

  # Disable deletion protection to allow terraform destroy
  deletion_protection = false

  # We can't create a cluster with no node pool, so we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.main.name
  subnetwork = google_compute_subnetwork.system.name

  # IP allocation for pods and services
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# System Node Pool
resource "google_container_node_pool" "system" {
  name     = "system"
  location = var.region
  cluster  = google_container_cluster.main.name

  # Fixed size node pool (per-zone count)
  node_count = 2

  # Private nodes (no public IP)
  network_config {
    enable_private_nodes = true
  }

  node_config {
    machine_type = var.system_machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      pool = "system"
    }

    # Network tags for LoadBalancer service firewall rules (HTTP/HTTPS)
    tags = ["system-nodes"]
  }
}

# SIP Node Pool
resource "google_container_node_pool" "sip" {
  name     = "sip"
  location = var.region
  cluster  = google_container_cluster.main.name

  # Fixed size node pool (per-zone count)
  node_count = var.sip_node_count

  node_config {
    machine_type = var.sip_machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      "voip-environment" = "sip"
    }

    # Network tags for firewall rules
    tags = ["sip-nodes"]

    # Taints to ensure only SIP workloads run here
    taint {
      key    = "sip"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}

# RTP Node Pool
resource "google_container_node_pool" "rtp" {
  name     = "rtp"
  location = var.region
  cluster  = google_container_cluster.main.name

  # Fixed size node pool (per-zone count)
  node_count = var.rtp_node_count

  node_config {
    machine_type = var.rtp_machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      "voip-environment" = "rtp"
    }

    # Network tags for firewall rules
    tags = ["rtp-nodes"]

    # Taints to ensure only RTP workloads run here
    taint {
      key    = "rtp"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}
