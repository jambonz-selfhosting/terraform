# Centralized logs with enforced retention: the GCP equivalent of the AWS
# templates' CloudWatch logging.
#
# - The VM runs Google's Ops Agent (installed by its startup script), which
#   sends the systemd journal (including SSH logins) and the jambonz
#   application logs to Cloud Logging.
# - A sink copies this deployment's VM logs into a log bucket of its own, kept
#   for var.log_retention_days. The project's _Default bucket and its retention
#   are left alone: this is your project.

resource "random_id" "bucket_suffix" {
  byte_length = 3
}

# Log bucket IDs stay reserved for 7 days after deletion, hence the suffix.
resource "google_logging_project_bucket_config" "jambonz" {
  project        = var.project_id
  location       = "global"
  bucket_id      = "${var.name_prefix}-logs-${random_id.bucket_suffix.hex}"
  retention_days = var.log_retention_days
  description    = "jambonz ${var.name_prefix}: VM and application logs"
}

resource "google_logging_project_sink" "jambonz" {
  name        = "${var.name_prefix}-logs"
  destination = "logging.googleapis.com/projects/${var.project_id}/locations/global/buckets/${google_logging_project_bucket_config.jambonz.bucket_id}"
  filter      = <<-EOT
    resource.type="gce_instance" AND labels."compute.googleapis.com/resource_name"=~"^${var.name_prefix}-"
  EOT

  # The bucket is in the same project, so the sink needs no writer identity
  # or IAM grant (its writer_identity is empty).
}

