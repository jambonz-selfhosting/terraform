# =============================================================================
# Database Server Template
# =============================================================================

data "exoscale_template" "jambonz_db" {
  zone       = var.zone
  name       = "jambonz-db-v${var.jambonz_version}"
  visibility = "private"
}

# =============================================================================
# Database Server (MySQL + Redis on dedicated VM)
# =============================================================================

resource "exoscale_compute_instance" "db" {
  zone = var.zone
  name = "${var.name_prefix}-db"

  type        = var.instance_type_db
  template_id = data.exoscale_template.jambonz_db.id
  disk_size   = var.disk_size_db
  ssh_keys    = local.ssh_keys

  network_interface {
    network_id = exoscale_private_network.jambonz.id
    ip_address = local.db_private_ip
  }

  security_group_ids = [
    exoscale_security_group.ssh.id,
    exoscale_security_group.internal.id
  ]

  user_data = templatefile("${path.module}/cloud-init-db.yaml", {
    mysql_user     = var.mysql_username
    mysql_password = local.db_password
    mysql_database = "jambones"
    ssh_public_key = local.ssh_public_key
  })

  labels = {
    role    = "db"
    cluster = var.name_prefix
  }
}
