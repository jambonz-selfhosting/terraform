# =============================================================================
# Internal Load Balancer for Recording Servers
# =============================================================================

# Note: Exoscale Network Load Balancer (NLB) for internal load balancing

resource "exoscale_nlb" "recording" {
  zone        = var.zone
  name        = "${var.name_prefix}-recording-lb"
  description = "Internal load balancer for recording servers"

  labels = {
    role    = "recording-lb"
    cluster = var.name_prefix
  }
}

# NLB Service for recording uploads (HTTP on port 80 -> 3000)
resource "exoscale_nlb_service" "recording_http" {
  zone        = var.zone
  name        = "recording-http"
  description = "HTTP service for recording uploads"

  nlb_id           = exoscale_nlb.recording.id
  instance_pool_id = exoscale_instance_pool.recording.id

  protocol    = "tcp"
  port        = 80
  target_port = 3000
  strategy    = "round-robin"

  healthcheck {
    mode     = "http"
    port     = 3000
    uri      = "/health"
    interval = 15
    timeout  = 5
    retries  = 2
  }
}
