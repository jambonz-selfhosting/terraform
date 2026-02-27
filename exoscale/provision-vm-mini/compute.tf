# =============================================================================
# Random Secrets Generation
# =============================================================================

# JWT/Encryption secret (32 characters, alphanumeric only)
resource "random_password" "encryption_secret" {
  length  = 32
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# Database password (16 characters)
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_"
  upper            = true
  lower            = true
  numeric          = true
}

# =============================================================================
# Locals
# =============================================================================

locals {
  # SSH key name for server creation
  ssh_key_name = var.ssh_public_key != "" ? exoscale_ssh_key.jambonz[0].name : var.ssh_key_name
}

# =============================================================================
# SSH Key
# =============================================================================

resource "exoscale_ssh_key" "jambonz" {
  count      = var.ssh_public_key != "" ? 1 : 0
  name       = "${var.name_prefix}-jambonz-key"
  public_key = var.ssh_public_key
}

# =============================================================================
# Jambonz Mini (All-in-One) Server
# =============================================================================

resource "exoscale_compute_instance" "mini" {
  zone               = var.zone
  name               = "${var.name_prefix}-jambonz-mini"
  template_id        = data.exoscale_template.jambonz_mini.id
  type               = var.instance_type
  disk_size          = var.disk_size
  ssh_keys           = [local.ssh_key_name]
  security_group_ids = [
    exoscale_security_group.jambonz.id,
    exoscale_security_group.ssh.id
  ]

  user_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    url_portal           = var.url_portal
    jwt_secret           = random_password.encryption_secret.result
    db_password          = random_password.db_password.result
    enable_otel          = var.enable_otel
    enable_pcaps         = var.enable_pcaps
    apiban_key           = var.apiban_key
    apiban_client_id     = var.apiban_client_id
    apiban_client_secret = var.apiban_client_secret
  }))

  labels = {
    role    = "mini"
    cluster = var.name_prefix
  }
}
