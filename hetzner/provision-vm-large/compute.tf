# =============================================================================
# Monitoring Server
# Must come up first — provides InfluxDB, Grafana, Homer, Jaeger
# =============================================================================

resource "hcloud_server" "monitoring" {
  name        = "${var.name_prefix}-monitoring"
  server_type = var.server_type_monitoring
  location    = var.location
  image       = var.image_monitoring
  ssh_keys    = [local.ssh_key_id]
  firewall_ids = [hcloud_firewall.monitoring.id]

  network {
    network_id = hcloud_network.jambonz.id
    ip         = local.monitoring_private_ip
  }

  labels = {
    role    = "monitoring"
    cluster = var.name_prefix
  }

  user_data = templatefile("${path.module}/cloud-init-monitoring.yaml", {
    url_portal         = var.url_portal
    vpc_cidr           = var.vpc_cidr
    data_volume_device = hcloud_volume.monitoring.linux_device
    enable_otel        = var.enable_otel
    enable_pcaps       = var.enable_pcaps
    ssh_public_key     = local.ssh_public_key
  })

  depends_on = [hcloud_network_subnet.jambonz]
}

resource "hcloud_volume" "monitoring" {
  name     = "${var.name_prefix}-monitoring-data"
  size     = var.volume_size_monitoring
  location = var.location
  format   = "ext4"
}

resource "hcloud_volume_attachment" "monitoring" {
  volume_id = hcloud_volume.monitoring.id
  server_id = hcloud_server.monitoring.id
  automount = true
}

# =============================================================================
# Web Server
# Portal, API, webapp — proxies grafana/homer to monitoring server
# =============================================================================

resource "hcloud_server" "web" {
  name        = "${var.name_prefix}-web"
  server_type = var.server_type_web
  location    = var.location
  image       = var.image_web
  ssh_keys    = [local.ssh_key_id]
  firewall_ids = [hcloud_firewall.web.id]

  network {
    network_id = hcloud_network.jambonz.id
  }

  labels = {
    role    = "web"
    cluster = var.name_prefix
  }

  user_data = templatefile("${path.module}/cloud-init-web.yaml", {
    mysql_host               = local.db_private_ip
    mysql_user               = var.mysql_username
    mysql_password           = local.db_password
    redis_host               = local.db_private_ip
    redis_port               = 6379
    jwt_secret               = random_password.encryption_secret.result
    url_portal               = var.url_portal
    vpc_cidr                 = var.vpc_cidr
    monitoring_private_ip    = local.monitoring_private_ip
    deploy_recording_cluster = var.deploy_recording_cluster
    ssh_public_key           = local.ssh_public_key
  })

  depends_on = [hcloud_network_subnet.jambonz, hcloud_server.monitoring, hcloud_server.db]
}

# =============================================================================
# RTP Servers
# Must come up before SIP servers (SIP needs RTP IPs for RTPENGINES config)
# =============================================================================

resource "hcloud_server" "rtp" {
  count       = var.rtp_count
  name        = "${var.name_prefix}-rtp-${count.index + 1}"
  server_type = var.server_type_rtp
  location    = var.location
  image       = var.image_rtp
  ssh_keys    = [local.ssh_key_id]
  firewall_ids = [hcloud_firewall.rtp.id]

  network {
    network_id = hcloud_network.jambonz.id
  }

  labels = {
    role    = "rtp"
    cluster = var.name_prefix
    index   = tostring(count.index + 1)
  }

  user_data = templatefile("${path.module}/cloud-init-rtp.yaml", {
    monitoring_private_ip = local.monitoring_private_ip
    vpc_cidr              = var.vpc_cidr
    enable_pcaps          = var.enable_pcaps
    redis_host            = local.db_private_ip
    redis_port            = 6379
    ssh_public_key        = local.ssh_public_key
  })

  depends_on = [hcloud_network_subnet.jambonz, hcloud_server.monitoring]
}

# =============================================================================
# SIP Servers
# Depends on RTP servers being up (needs their private IPs)
# =============================================================================

resource "hcloud_server" "sip" {
  count       = var.sip_count
  name        = "${var.name_prefix}-sip-${count.index + 1}"
  server_type = var.server_type_sip
  location    = var.location
  image       = var.image_sip
  ssh_keys    = [local.ssh_key_id]
  firewall_ids = [hcloud_firewall.sip.id]

  network {
    network_id = hcloud_network.jambonz.id
  }

  labels = {
    role    = "sip"
    cluster = var.name_prefix
    index   = tostring(count.index + 1)
  }

  user_data = templatefile("${path.module}/cloud-init-sip.yaml", {
    mysql_host           = local.db_private_ip
    mysql_user           = var.mysql_username
    mysql_password       = local.db_password
    redis_host           = local.db_private_ip
    redis_port           = 6379
    jwt_secret           = random_password.encryption_secret.result
    vpc_cidr             = var.vpc_cidr
    sip_index            = count.index + 1
    monitoring_private_ip = local.monitoring_private_ip
    enable_pcaps         = var.enable_pcaps
    rtp_private_ips      = join(",", [for rtp in hcloud_server.rtp : tolist(rtp.network)[0].ip])
    ssh_public_key       = local.ssh_public_key
    apiban_key           = var.apiban_key
    apiban_client_id     = var.apiban_client_id
    apiban_client_secret = var.apiban_client_secret
  })

  depends_on = [hcloud_network_subnet.jambonz, hcloud_server.rtp]
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
    web_monitoring_private_ip = local.monitoring_private_ip
    enable_otel               = var.enable_otel
    recording_ws_base_url     = var.deploy_recording_cluster && length(hcloud_server.recording) > 0 ? "ws://${tolist(hcloud_server.recording[0].network)[0].ip}:3000" : "ws://${tolist(hcloud_server.web.network)[0].ip}:3017"
    ssh_public_key           = local.ssh_public_key
    krisp_license_key        = var.krisp_license_key
  })

  depends_on = [hcloud_network_subnet.jambonz, hcloud_server.monitoring, hcloud_server.db]
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
    web_monitoring_private_ip = local.monitoring_private_ip
    ssh_public_key           = local.ssh_public_key
  })

  depends_on = [hcloud_network_subnet.jambonz, hcloud_server.monitoring, hcloud_server.db]
}
