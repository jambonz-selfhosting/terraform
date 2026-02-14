# Network Load Balancer for Recording Servers on OCI
# Only created if deploy_recording_cluster is true

# ------------------------------------------------------------------------------
# RECORDING SERVER NETWORK LOAD BALANCER
# ------------------------------------------------------------------------------

resource "oci_network_load_balancer_network_load_balancer" "recording" {
  count = var.deploy_recording_cluster ? 1 : 0

  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-recording-nlb"
  subnet_id      = oci_core_subnet.private.id

  is_private                     = true
  is_preserve_source_destination = false

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "recording"
  }
}

# Backend Set
resource "oci_network_load_balancer_backend_set" "recording" {
  count = var.deploy_recording_cluster ? 1 : 0

  name                     = "recording-backend-set"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.recording[0].id
  policy                   = "FIVE_TUPLE"

  health_checker {
    protocol           = "HTTP"
    port               = 3000
    url_path           = "/health"
    return_code        = 200
    interval_in_millis = 15000
    timeout_in_millis  = 3000
    retries            = 2
  }
}

# Backends (one for each recording instance)
resource "oci_network_load_balancer_backend" "recording" {
  count = var.deploy_recording_cluster ? var.recording_count : 0

  backend_set_name         = oci_network_load_balancer_backend_set.recording[0].name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.recording[0].id
  port                     = 3000
  target_id                = oci_core_instance.recording[count.index].id
}

# Listener
resource "oci_network_load_balancer_listener" "recording" {
  count = var.deploy_recording_cluster ? 1 : 0

  default_backend_set_name = oci_network_load_balancer_backend_set.recording[0].name
  name                     = "recording-listener"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.recording[0].id
  port                     = 80
  protocol                 = "TCP"
}
