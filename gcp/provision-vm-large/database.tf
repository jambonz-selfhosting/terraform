# Cloud SQL MySQL configuration for jambonz on GCP
#
# Private IP only, encrypted at rest (always on in Cloud SQL), a standby in a
# second zone with automatic failover, 30 days of backups with point-in-time
# recovery, deletion protection, and connection auditing (cloudsql_mysql_audit).

# ------------------------------------------------------------------------------
# CLOUD SQL MYSQL INSTANCE
# ------------------------------------------------------------------------------

resource "google_sql_database_instance" "jambonz" {
  name             = "${var.name_prefix}-mysql"
  database_version = "MYSQL_8_0"
  region           = var.region

  # Both the terraform-side and the API-side protection. With either on, the
  # instance can't be deleted -- by terraform destroy, the console or gcloud --
  # until you set mysql_deletion_protection = false and apply.
  deletion_protection = var.mysql_deletion_protection

  settings {
    tier                        = var.mysql_tier
    availability_type           = var.mysql_high_availability ? "REGIONAL" : "ZONAL"
    deletion_protection_enabled = var.mysql_deletion_protection
    disk_size                   = var.mysql_disk_size
    disk_type                   = "PD_SSD"
    disk_autoresize             = true

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.jambonz.id
      enable_private_path_for_google_cloud_services = true
      # TODO(soc2): ENCRYPTED_ONLY once drachtio and upload-recordings are
      # confirmed to connect over TLS. The Node apps can; the C++ components are
      # untested. Traffic stays on the private VPC peering.
      ssl_mode = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
    }

    backup_configuration {
      enabled                        = true
      binary_log_enabled             = true
      start_time                     = "03:00"
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }
    }

    database_flags {
      name  = "max_connections"
      value = "300"
    }

    # Load the audit plugin. The rule that records connections (logins, logouts,
    # failed logins) is created by the web server's startup script, which already
    # holds the database credentials; audit events go to Cloud Logging.
    database_flags {
      name  = "cloudsql_mysql_audit"
      value = "ON"
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
