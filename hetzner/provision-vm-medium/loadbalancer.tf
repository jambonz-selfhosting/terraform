# =============================================================================
# Internal Load Balancer for Recording Servers
# =============================================================================

resource "hcloud_load_balancer" "recording" {
  name               = "${var.name_prefix}-recording-lb"
  load_balancer_type = "lb11"
  location           = var.location

  labels = {
    role    = "recording-lb"
    cluster = var.name_prefix
  }
}

resource "hcloud_load_balancer_network" "recording" {
  load_balancer_id = hcloud_load_balancer.recording.id
  network_id       = hcloud_network.jambonz.id

  depends_on = [hcloud_network_subnet.jambonz]
}

resource "hcloud_load_balancer_service" "recording_http" {
  load_balancer_id = hcloud_load_balancer.recording.id
  protocol         = "tcp"
  listen_port      = 80
  destination_port = 3000

  health_check {
    protocol = "http"
    port     = 3000
    interval = 15
    timeout  = 5
    retries  = 2

    http {
      path         = "/health"
      status_codes = ["2??"]
    }
  }
}

resource "hcloud_load_balancer_target" "recording" {
  count            = var.recording_server_count
  load_balancer_id = hcloud_load_balancer.recording.id
  type             = "server"
  server_id        = hcloud_server.recording[count.index].id
  use_private_ip   = true

  depends_on = [hcloud_load_balancer_network.recording]
}
