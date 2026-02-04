# ------------------------------------------------------------------------------
# LOCAL IMAGE COPIES
# Copy public images to customer project for MIG independence.
# These run first (no dependencies) to fail fast on permission/quota issues.
# ------------------------------------------------------------------------------

resource "google_compute_image" "feature_server" {
  name         = "${var.name_prefix}-fs-image"
  source_image = var.feature_server_image
  project      = var.project_id

  description = "Local copy of jambonz feature server image"

  labels = {
    environment = var.environment
    service     = "jambonz"
    role        = "feature-server"
  }
}

resource "google_compute_image" "recording" {
  count        = var.deploy_recording_cluster ? 1 : 0
  name         = "${var.name_prefix}-recording-image"
  source_image = var.recording_image
  project      = var.project_id

  description = "Local copy of jambonz recording server image"

  labels = {
    environment = var.environment
    service     = "jambonz"
    role        = "recording"
  }
}
