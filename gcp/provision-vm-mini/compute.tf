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
      type  = var.disk_type
    }
  }

  network_interface {
    network    = google_compute_network.jambonz.id
    subnetwork = google_compute_subnetwork.public.id

    access_config {
      nat_ip = google_compute_address.mini.address
    }
  }

  service_account {
    email  = google_service_account.jambonz.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  metadata_startup_script = templatefile("${path.module}/startup-script-mini.sh", {
    common = templatefile("${path.module}/startup-common.sh", {
      project_id    = var.project_id
      secret_prefix = var.name_prefix
    })
    url_portal        = var.url_portal
    apiban_key_set    = var.apiban_key != ""
    apiban_client_id  = var.apiban_client_id
    apiban_client_set = var.apiban_client_secret != ""
    krisp_key_set     = var.krisp_license_key != ""
  })

  labels = {
    environment = var.environment
    service     = "jambonz"
    role        = "mini"
  }

  depends_on = [
    google_secret_manager_secret_version.jambonz,
    google_secret_manager_secret_iam_member.jambonz,
    google_project_iam_member.log_writer,
    google_compute_address.mini,
    google_compute_subnetwork.public
  ]
}
