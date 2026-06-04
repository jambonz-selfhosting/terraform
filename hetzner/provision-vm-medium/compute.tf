# =============================================================================
# Web/Monitoring Server
# =============================================================================

resource "hcloud_server" "web_monitoring" {
  name        = "${var.name_prefix}-web-monitoring"
  server_type = var.server_type_web
  location    = var.location
  image       = var.image_web_monitoring
  ssh_keys    = [local.ssh_key_id]
  firewall_ids = [hcloud_firewall.web_monitoring.id]

  network {
    network_id = hcloud_network.jambonz.id
    ip         = local.web_monitoring_private_ip
  }

  labels = {
    role    = "web-monitoring"
    cluster = var.name_prefix
  }

  user_data = templatefile("${path.module}/cloud-init-web-monitoring.yaml", {
    mysql_host               = local.db_private_ip
    mysql_port               = 3306
    mysql_user               = var.mysql_username
    mysql_password           = local.db_password
    mysql_database           = "jambones"
    redis_host               = local.db_private_ip
    redis_port               = 6379
    jwt_secret               = random_password.encryption_secret.result
    url_portal               = var.url_portal
    vpc_cidr                 = var.vpc_cidr
    web_monitoring_private_ip = local.web_monitoring_private_ip
    deploy_recording_cluster = var.deploy_recording_cluster
    enable_otel              = var.enable_otel
    enable_pcaps             = var.enable_pcaps
    data_volume_device       = hcloud_volume.web_monitoring.linux_device
    ssh_public_key           = local.ssh_public_key
  })

  depends_on = [hcloud_network_subnet.jambonz, hcloud_server.db]
}

resource "hcloud_volume" "web_monitoring" {
  name     = "${var.name_prefix}-web-monitoring-data"
  size     = var.volume_size_web
  location = var.location
  format   = "ext4"
}

resource "hcloud_volume_attachment" "web_monitoring" {
  volume_id = hcloud_volume.web_monitoring.id
  server_id = hcloud_server.web_monitoring.id
  automount = true
}

# =============================================================================
# SBC Servers
# =============================================================================

resource "hcloud_server" "sbc" {
  count       = var.sbc_count
  name        = "${var.name_prefix}-sbc-${count.index + 1}"
  server_type = var.server_type_sbc
  location    = var.location
  image       = var.image_sbc
  ssh_keys    = [local.ssh_key_id]
  firewall_ids = [hcloud_firewall.sbc.id]

  network {
    network_id = hcloud_network.jambonz.id
  }

  labels = {
    role    = "sbc"
    cluster = var.name_prefix
    index   = tostring(count.index + 1)
  }

  user_data = templatefile("${path.module}/cloud-init-sbc.yaml", {
    mysql_host           = local.db_private_ip
    mysql_port           = 3306
    mysql_user           = var.mysql_username
    mysql_password       = local.db_password
    mysql_database       = "jambones"
    redis_host           = local.db_private_ip
    redis_port           = 6379
    jwt_secret           = random_password.encryption_secret.result
    url_portal           = var.url_portal
    vpc_cidr             = var.vpc_cidr
    sbc_index                = count.index + 1
    web_monitoring_private_ip = local.web_monitoring_private_ip
    enable_pcaps             = var.enable_pcaps
    ssh_public_key           = local.ssh_public_key
    apiban_key               = var.apiban_key
    apiban_client_id     = var.apiban_client_id
    apiban_client_secret = var.apiban_client_secret
  })

  depends_on = [hcloud_network_subnet.jambonz, hcloud_server.db]
}


# =============================================================================
# Feature Servers
# =============================================================================

resource "hcloud_server" "feature_server" {
  count       = var.feature_server_count
  name        = "${var.name_prefix}-fs-${count.index + 1}"
  server_type = var.server_type_feature
  location    = var.location
  image       = var.image_feature_server
  ssh_keys    = [local.ssh_key_id]
  firewall_ids = [hcloud_firewall.ssh_only.id]

  network {
    network_id = hcloud_network.jambonz.id
  }

  labels = {
    role    = "feature-server"
    cluster = var.name_prefix
    index   = tostring(count.index + 1)
  }

  user_data = templatefile("${path.module}/cloud-init-feature-server.yaml", {
    mysql_host               = local.db_private_ip
    mysql_user               = var.mysql_username
    mysql_password           = local.db_password
    redis_host               = local.db_private_ip
    redis_port               = 6379
    jwt_secret               = random_password.encryption_secret.result
    url_portal               = var.url_portal
    vpc_cidr                 = var.vpc_cidr
    web_monitoring_private_ip = local.web_monitoring_private_ip
    enable_otel               = var.enable_otel
    recording_ws_base_url     = var.deploy_recording_cluster && length(hcloud_server.recording) > 0 ? "ws://${tolist(hcloud_server.recording[0].network)[0].ip}:3000" : "ws://${local.web_monitoring_private_ip}:3017"
    ssh_public_key           = local.ssh_public_key
    krisp_license_key        = var.krisp_license_key
  })

  depends_on = [hcloud_network_subnet.jambonz, hcloud_server.db]
}


# =============================================================================
# Recording Servers (Optional)
# =============================================================================

resource "hcloud_server" "recording" {
  count       = var.deploy_recording_cluster ? var.recording_server_count : 0
  name        = "${var.name_prefix}-rec-${count.index + 1}"
  server_type = var.server_type_recording
  location    = var.location
  image       = var.image_recording
  ssh_keys    = [local.ssh_key_id]
  firewall_ids = [hcloud_firewall.ssh_only.id]

  network {
    network_id = hcloud_network.jambonz.id
  }

  labels = {
    role    = "recording"
    cluster = var.name_prefix
    index   = tostring(count.index + 1)
  }

  user_data = templatefile("${path.module}/cloud-init-recording.yaml", {
    mysql_host               = local.db_private_ip
    mysql_user               = var.mysql_username
    mysql_password           = local.db_password
    jwt_secret               = random_password.encryption_secret.result
    web_monitoring_private_ip = local.web_monitoring_private_ip
    ssh_public_key           = local.ssh_public_key
  })

  depends_on = [hcloud_network_subnet.jambonz, hcloud_server.db]
}

