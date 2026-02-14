# OCI MySQL HeatWave Database System for jambonz large cluster

# Custom MySQL configuration to disable reverse DNS lookups on client connections.
# Without this, every connection incurs a ~10s timeout resolving private VCN IPs.
resource "oci_mysql_mysql_configuration" "jambonz" {
  compartment_id = var.compartment_id
  shape_name     = var.mysql_shape
  display_name   = "${var.name_prefix}-mysql-config"

  variables {
    skip_name_resolve = true
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

resource "oci_mysql_mysql_db_system" "jambonz" {
  compartment_id      = var.compartment_id
  availability_domain = local.availability_domain
  display_name        = "${var.name_prefix}-mysql"

  shape_name       = var.mysql_shape
  configuration_id = oci_mysql_mysql_configuration.jambonz.id
  subnet_id        = oci_core_subnet.private.id

  admin_username = var.mysql_username
  admin_password = local.db_password

  data_storage_size_in_gb = var.mysql_storage_size

  # Backup configuration
  backup_policy {
    is_enabled        = true
    retention_in_days = 7
    window_start_time = "03:00"
  }

  # Maintenance window
  maintenance {
    window_start_time = "sun 04:00"
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "database"
  }
}

# Wait for MySQL to be available and create the jambones database
resource "null_resource" "mysql_setup" {
  depends_on = [oci_mysql_mysql_db_system.jambonz]

  # This is handled by cloud-init on the web-monitoring instance
  # which connects to MySQL and creates the database
}
