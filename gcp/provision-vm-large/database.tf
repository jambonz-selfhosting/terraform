# Cloud SQL MySQL configuration for jambonz on GCP
# Private IP, no SSL requirement

# ------------------------------------------------------------------------------
# CLOUD SQL MYSQL INSTANCE
# ------------------------------------------------------------------------------

resource "google_sql_database_instance" "jambonz" {
  name             = "${var.name_prefix}-mysql"
  database_version = "MYSQL_8_0"
  region           = var.region

  deletion_protection = false

  settings {
    tier              = var.mysql_tier
    availability_type = "ZONAL"
    disk_size         = var.mysql_disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.jambonz.id
      enable_private_path_for_google_cloud_services = true
      # No SSL required - use ssl_mode instead of deprecated require_ssl
      ssl_mode = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
    }

    backup_configuration {
      enabled            = true
      binary_log_enabled = true
      start_time         = "03:00"
    }

    database_flags {
      name  = "max_connections"
      value = "300"
    }

    user_labels = {
      environment = var.environment
      service     = "jambonz"
    }
  }

  depends_on = [google_service_networking_connection.private_services]
}

# Database
resource "google_sql_database" "jambonz" {
  name     = "jambones"
  instance = google_sql_database_instance.jambonz.name
  charset  = "utf8mb4"
}

# Database user
resource "google_sql_user" "jambonz" {
  name     = var.mysql_username
  instance = google_sql_database_instance.jambonz.name
  password = local.db_password
  host     = "%"
}
