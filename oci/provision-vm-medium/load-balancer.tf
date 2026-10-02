# Network Load Balancer for Recording Servers on OCI

# ------------------------------------------------------------------------------
# RECORDING SERVER NETWORK LOAD BALANCER
# ------------------------------------------------------------------------------

resource "oci_network_load_balancer_network_load_balancer" "recording" {
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
  name                     = "recording-backend-set"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.recording.id
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
  count = var.recording_count

  backend_set_name         = oci_network_load_balancer_backend_set.recording.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.recording.id
  port                     = 3000
  target_id                = oci_core_instance.recording[count.index].id
}

# Listener
resource "oci_network_load_balancer_listener" "recording" {
  default_backend_set_name = oci_network_load_balancer_backend_set.recording.name
  name                     = "recording-listener"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.recording.id
  port                     = 80
  protocol                 = "TCP"
}
