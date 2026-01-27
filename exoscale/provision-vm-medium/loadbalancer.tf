# =============================================================================
# Internal Load Balancer for Recording Servers
# =============================================================================

# Note: Exoscale Network Load Balancer (NLB) for internal load balancing
# Only created if recording cluster is deployed

resource "exoscale_nlb" "recording" {
  count = var.deploy_recording_cluster ? 1 : 0

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
  count = var.deploy_recording_cluster ? 1 : 0

  zone        = var.zone
  name        = "recording-http"
  description = "HTTP service for recording uploads"

  nlb_id           = exoscale_nlb.recording[0].id
  instance_pool_id = exoscale_instance_pool.recording[0].id

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
