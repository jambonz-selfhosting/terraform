# Compute resources for jambonz mini (single VM) on GCP
# All-in-one deployment with local MySQL, Redis, and monitoring

# ------------------------------------------------------------------------------
# STATIC IP ADDRESS
# ------------------------------------------------------------------------------

resource "google_compute_address" "mini" {
  name   = "${var.name_prefix}-mini-ip"
  region = var.region
}

# ------------------------------------------------------------------------------
# MINI SERVER (ALL-IN-ONE)
# ------------------------------------------------------------------------------

resource "google_compute_instance" "mini" {
  name         = "${var.name_prefix}-mini"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["jambonz"]

  boot_disk {
    initialize_params {
      image = var.mini_image
      size  = var.disk_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.jambonz.id
    subnetwork = google_compute_subnetwork.public.id

    access_config {
      nat_ip = google_compute_address.mini.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  metadata_startup_script = templatefile("${path.module}/startup-script-mini.sh", {
    db_password          = random_password.db_password.result
    jwt_secret           = random_password.jwt_secret.result
    url_portal           = var.url_portal
    apiban_key           = var.apiban_key
    apiban_client_id     = var.apiban_client_id
    apiban_client_secret = var.apiban_client_secret
  })

  labels = {
    environment = var.environment
    service     = "jambonz"
    role        = "mini"
  }

  depends_on = [
    google_compute_address.mini,
    google_compute_subnetwork.public
  ]
}
