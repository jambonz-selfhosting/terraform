# Compute resources for jambonz large cluster on GCP
# Fully separated architecture: Web, Monitoring, SIP, RTP as individual VMs

# ------------------------------------------------------------------------------
# WEB SERVER
# ------------------------------------------------------------------------------

# Static external IP for Web server
resource "google_compute_address" "web" {
  name   = "${var.name_prefix}-web-ip"
  region = var.region
}

resource "google_compute_instance" "web" {
  name         = "${var.name_prefix}-web"
  machine_type = var.web_machine_type
  zone         = var.zone

  tags = ["jambonz", "jambonz-web"]

  boot_disk {
    initialize_params {
      image = var.web_image
      size  = var.web_disk_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.jambonz.id
    subnetwork = google_compute_subnetwork.public.id

    access_config {
      nat_ip = google_compute_address.web.address
    }
  }

  service_account {
    email  = google_service_account.jambonz.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  metadata_startup_script = templatefile("${path.module}/startup-script-web.sh", {
    mysql_host               = google_sql_database_instance.jambonz.private_ip_address
    mysql_user               = var.mysql_username
    mysql_password           = local.db_password
    redis_host               = google_redis_instance.jambonz.host
    redis_port               = google_redis_instance.jambonz.port
    jwt_secret               = random_password.encryption_secret.result
    url_portal               = var.url_portal
    vpc_cidr                 = var.vpc_cidr
    monitoring_private_ip    = google_compute_instance.monitoring.network_interface[0].network_ip
    deploy_recording_cluster = var.deploy_recording_cluster
  })

  labels = {
    environment = var.environment
    service     = "jambonz"
    role        = "web"
  }

  depends_on = [
    google_sql_database_instance.jambonz,
    google_redis_instance.jambonz,
    google_compute_instance.monitoring
  ]
}

# ------------------------------------------------------------------------------
# MONITORING SERVER
# ------------------------------------------------------------------------------

# Static external IP for Monitoring server
resource "google_compute_address" "monitoring" {
  name   = "${var.name_prefix}-monitoring-ip"
  region = var.region
}

resource "google_compute_instance" "monitoring" {
  name         = "${var.name_prefix}-monitoring"
  machine_type = var.monitoring_machine_type
  zone         = var.zone

  tags = ["jambonz", "jambonz-monitoring"]

  boot_disk {
    initialize_params {
      image = var.monitoring_image
      size  = var.monitoring_disk_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.jambonz.id
    subnetwork = google_compute_subnetwork.public.id

    access_config {
      nat_ip = google_compute_address.monitoring.address
    }
  }

  service_account {
    email  = google_service_account.jambonz.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  metadata_startup_script = templatefile("${path.module}/startup-script-monitoring.sh", {
    url_portal = var.url_portal
    vpc_cidr   = var.vpc_cidr
  })

  labels = {
    environment = var.environment
    service     = "jambonz"
    role        = "monitoring"
  }
}

# ------------------------------------------------------------------------------
# SIP SERVER VIRTUAL MACHINES
# ------------------------------------------------------------------------------

# Static external IPs for SIP server instances
resource "google_compute_address" "sip" {
  count  = var.sip_count
  name   = "${var.name_prefix}-sip-ip-${count.index}"
  region = var.region
}

resource "google_compute_instance" "sip" {
  count        = var.sip_count
  name         = "${var.name_prefix}-sip-${count.index}"
  machine_type = var.sip_machine_type
  zone         = var.zone

  tags = ["jambonz", "jambonz-sip"]

  boot_disk {
    initialize_params {
      image = var.sip_image
      size  = var.sip_disk_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.jambonz.id
    subnetwork = google_compute_subnetwork.public.id

    access_config {
      nat_ip = google_compute_address.sip[count.index].address
    }
  }

  service_account {
    email  = google_service_account.jambonz.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  metadata_startup_script = templatefile("${path.module}/startup-script-sip.sh", {
    mysql_host            = google_sql_database_instance.jambonz.private_ip_address
    mysql_user            = var.mysql_username
    mysql_password        = local.db_password
    redis_host            = google_redis_instance.jambonz.host
    redis_port            = google_redis_instance.jambonz.port
    jwt_secret            = random_password.encryption_secret.result
    monitoring_private_ip = google_compute_instance.monitoring.network_interface[0].network_ip
    vpc_cidr              = var.vpc_cidr
    enable_pcaps          = var.enable_pcaps
    apiban_key            = var.apiban_key
    apiban_client_id      = var.apiban_client_id
    apiban_client_secret  = var.apiban_client_secret
    # Pass all RTP server private IPs as comma-separated list
    rtp_private_ips       = join(",", [for rtp in google_compute_instance.rtp : rtp.network_interface[0].network_ip])
  })

  labels = {
    environment = var.environment
    service     = "jambonz"
    role        = "sip"
  }

  depends_on = [
    google_compute_instance.monitoring,
    google_compute_instance.rtp
  ]
}

# ------------------------------------------------------------------------------
# RTP SERVER VIRTUAL MACHINES
# ------------------------------------------------------------------------------

# Static external IPs for RTP server instances
resource "google_compute_address" "rtp" {
  count  = var.rtp_count
  name   = "${var.name_prefix}-rtp-ip-${count.index}"
  region = var.region
}

resource "google_compute_instance" "rtp" {
  count        = var.rtp_count
  name         = "${var.name_prefix}-rtp-${count.index}"
  machine_type = var.rtp_machine_type
  zone         = var.zone

  tags = ["jambonz", "jambonz-rtp"]

  boot_disk {
    initialize_params {
      image = var.rtp_image
      size  = var.rtp_disk_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = google_compute_network.jambonz.id
    subnetwork = google_compute_subnetwork.public.id

    access_config {
      nat_ip = google_compute_address.rtp[count.index].address
    }
  }

  service_account {
    email  = google_service_account.jambonz.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  metadata_startup_script = templatefile("${path.module}/startup-script-rtp.sh", {
    monitoring_private_ip = google_compute_instance.monitoring.network_interface[0].network_ip
    vpc_cidr              = var.vpc_cidr
    enable_pcaps          = var.enable_pcaps
  })

  labels = {
    environment = var.environment
    service     = "jambonz"
    role        = "rtp"
  }

  depends_on = [
    google_compute_instance.monitoring
  ]
}

# ------------------------------------------------------------------------------
# FEATURE SERVER MANAGED INSTANCE GROUP
# ------------------------------------------------------------------------------

# Instance template for Feature Servers
resource "google_compute_instance_template" "feature_server" {
  name_prefix  = "${var.name_prefix}-fs-"
  machine_type = var.feature_server_machine_type
  region       = var.region

  tags = ["jambonz", "jambonz-fs"]

  disk {
    source_image = var.feature_server_image
    auto_delete  = true
    boot         = true
    disk_type    = "pd-ssd"
    disk_size_gb = var.feature_server_disk_size
  }

  network_interface {
    network    = google_compute_network.jambonz.id
    subnetwork = google_compute_subnetwork.public.id

    # Public IP for Feature Servers (optional - Cloud NAT handles outbound if disabled)
    dynamic "access_config" {
      for_each = var.feature_server_public_ip ? [1] : []
      content {
        network_tier = "PREMIUM"
      }
    }
  }

  service_account {
    email  = google_service_account.jambonz.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  metadata_startup_script = templatefile("${path.module}/startup-script-feature-server.sh", {
    mysql_host               = google_sql_database_instance.jambonz.private_ip_address
    mysql_user               = var.mysql_username
    mysql_password           = local.db_password
    redis_host               = google_redis_instance.jambonz.host
    redis_port               = google_redis_instance.jambonz.port
    jwt_secret               = random_password.encryption_secret.result
    monitoring_private_ip    = google_compute_instance.monitoring.network_interface[0].network_ip
    vpc_cidr                 = var.vpc_cidr
    url_portal               = var.url_portal
    recording_ws_base_url    = var.deploy_recording_cluster ? "ws://${google_compute_forwarding_rule.recording[0].ip_address}" : "ws://${google_compute_instance.web.network_interface[0].network_ip}:3017"
    scale_in_timeout_seconds = var.scale_in_timeout_seconds
    project_id               = var.project_id
    zone                     = var.zone
  })

  labels = {
    environment = var.environment
    service     = "jambonz"
    role        = "feature-server"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Health check for Feature Servers
resource "google_compute_health_check" "feature_server" {
  name                = "${var.name_prefix}-fs-health"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 3000
    request_path = "/"
  }
}

# Managed Instance Group for Feature Servers
resource "google_compute_instance_group_manager" "feature_server" {
  name               = "${var.name_prefix}-fs-mig"
  base_instance_name = "${var.name_prefix}-fs"
  zone               = var.zone
  target_size        = var.feature_server_target_size

  version {
    instance_template = google_compute_instance_template.feature_server.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.feature_server.id
    initial_delay_sec = 300
  }

  update_policy {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    max_unavailable_fixed          = 1
    max_surge_fixed                = 1
  }

  named_port {
    name = "http"
    port = 3000
  }

  depends_on = [
    google_compute_instance.monitoring
  ]
}

# ------------------------------------------------------------------------------
# RECORDING SERVER CLUSTER (CONDITIONAL)
# ------------------------------------------------------------------------------

# Internal Load Balancer for Recording Servers
resource "google_compute_forwarding_rule" "recording" {
  count                 = var.deploy_recording_cluster ? 1 : 0
  name                  = "${var.name_prefix}-recording-lb"
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.recording[0].id
  ports                 = ["3000"]
  network               = google_compute_network.jambonz.id
  subnetwork            = google_compute_subnetwork.public.id
}

resource "google_compute_region_backend_service" "recording" {
  count                 = var.deploy_recording_cluster ? 1 : 0
  name                  = "${var.name_prefix}-recording-backend"
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  protocol              = "TCP"

  backend {
    group          = google_compute_instance_group_manager.recording[0].instance_group
    balancing_mode = "CONNECTION"
  }

  health_checks = [google_compute_health_check.recording[0].id]
}

resource "google_compute_health_check" "recording" {
  count               = var.deploy_recording_cluster ? 1 : 0
  name                = "${var.name_prefix}-recording-health"
  check_interval_sec  = 15
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = 3000
    request_path = "/health"
  }
}

# Instance template for Recording Servers
resource "google_compute_instance_template" "recording" {
  count        = var.deploy_recording_cluster ? 1 : 0
  name_prefix  = "${var.name_prefix}-recording-"
  machine_type = var.recording_machine_type
  region       = var.region

  tags = ["jambonz", "jambonz-recording"]

  disk {
    source_image = var.recording_image
    auto_delete  = true
    boot         = true
    disk_type    = "pd-ssd"
    disk_size_gb = var.recording_disk_size
  }

  network_interface {
    network    = google_compute_network.jambonz.id
    subnetwork = google_compute_subnetwork.public.id
    # No public IP for recording servers - internal only
  }

  service_account {
    email  = google_service_account.jambonz.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  metadata_startup_script = templatefile("${path.module}/startup-script-recording.sh", {
    mysql_host            = google_sql_database_instance.jambonz.private_ip_address
    mysql_user            = var.mysql_username
    mysql_password        = local.db_password
    jwt_secret            = random_password.encryption_secret.result
    monitoring_private_ip = google_compute_instance.monitoring.network_interface[0].network_ip
  })

  labels = {
    environment = var.environment
    service     = "jambonz"
    role        = "recording"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Managed Instance Group for Recording Servers
resource "google_compute_instance_group_manager" "recording" {
  count              = var.deploy_recording_cluster ? 1 : 0
  name               = "${var.name_prefix}-recording-mig"
  base_instance_name = "${var.name_prefix}-recording"
  zone               = var.zone
  target_size        = var.recording_target_size

  version {
    instance_template = google_compute_instance_template.recording[0].id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.recording[0].id
    initial_delay_sec = 300
  }

  update_policy {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    max_unavailable_fixed          = 1
    max_surge_fixed                = 1
  }

  named_port {
    name = "http"
    port = 3000
  }

  depends_on = [
    google_compute_instance.monitoring
  ]
}

# Autoscaler for Recording Servers
resource "google_compute_autoscaler" "recording" {
  count  = var.deploy_recording_cluster ? 1 : 0
  name   = "${var.name_prefix}-recording-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.recording[0].id

  autoscaling_policy {
    min_replicas    = var.recording_min_replicas
    max_replicas    = var.recording_max_replicas
    cooldown_period = 300

    cpu_utilization {
      target = 0.7
    }
  }
}
