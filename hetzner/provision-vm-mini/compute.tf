# =============================================================================
# Jambonz Mini (All-in-One) Server
# =============================================================================

resource "hcloud_server" "mini" {
  name         = "${var.name_prefix}-jambonz-mini"
  server_type  = var.server_type
  location     = var.location
  image        = var.image_mini
  ssh_keys     = [local.ssh_key_id]
  firewall_ids = [hcloud_firewall.mini.id]

  labels = {
    role    = "mini"
    cluster = var.name_prefix
  }

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    ssh_public_key       = local.ssh_public_key
    url_portal           = var.url_portal
    jwt_secret           = random_password.encryption_secret.result
    db_password          = random_password.db_password.result
    enable_otel          = var.enable_otel
    enable_pcaps         = var.enable_pcaps
    apiban_key           = var.apiban_key
    apiban_client_id     = var.apiban_client_id
    apiban_client_secret = var.apiban_client_secret
    krisp_license_key    = var.krisp_license_key
  })
}
