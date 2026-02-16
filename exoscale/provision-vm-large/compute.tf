# =============================================================================
# Template Lookups
# =============================================================================

data "exoscale_template" "jambonz_web" {
  zone       = var.zone
  name       = "jambonz-web-v${var.jambonz_version}"
  visibility = "private"
}

data "exoscale_template" "jambonz_monitoring" {
  zone       = var.zone
  name       = "jambonz-monitoring-v${var.jambonz_version}"
  visibility = "private"
}

data "exoscale_template" "jambonz_sip" {
  zone       = var.zone
  name       = "jambonz-sip-v${var.jambonz_version}"
  visibility = "private"
}

data "exoscale_template" "jambonz_rtp" {
  zone       = var.zone
  name       = "jambonz-rtp-v${var.jambonz_version}"
  visibility = "private"
}

data "exoscale_template" "jambonz_fs" {
  zone       = var.zone
  name       = "jambonz-fs-v${var.jambonz_version}"
  visibility = "private"
}

data "exoscale_template" "jambonz_recording" {
  zone       = var.zone
  name       = "jambonz-recording-v${var.jambonz_version}"
  visibility = "private"
}

# =============================================================================
# Monitoring Server
# =============================================================================

# Elastic IP for monitoring server
resource "exoscale_elastic_ip" "monitoring" {
  zone        = var.zone
  description = "${var.name_prefix} monitoring public IP"

  healthcheck {
    mode         = "tcp"
    port         = 9080
    interval     = 10
    timeout      = 3
    strikes_ok   = 2
    strikes_fail = 3
  }
}

# Monitoring compute instance
resource "exoscale_compute_instance" "monitoring" {
  zone = var.zone
  name = "${var.name_prefix}-monitoring"

  type        = var.instance_type_monitoring
  template_id = data.exoscale_template.jambonz_monitoring.id
  disk_size   = var.disk_size_monitoring
  ssh_keys    = local.ssh_keys

  elastic_ip_ids = [exoscale_elastic_ip.monitoring.id]

  network_interface {
    network_id = exoscale_private_network.jambonz.id
    ip_address = local.monitoring_private_ip
  }

  security_group_ids = [
    exoscale_security_group.ssh.id,
    exoscale_security_group.monitoring.id,
    exoscale_security_group.internal.id
  ]

  user_data = templatefile("${path.module}/cloud-init-monitoring.yaml", {
    url_portal     = var.url_portal
    vpc_cidr       = var.vpc_cidr
    ssh_public_key = local.ssh_public_key
  })

  labels = {
    role    = "monitoring"
    cluster = var.name_prefix
  }
}

# =============================================================================
# Web Server
# =============================================================================

# Elastic IP for web server
resource "exoscale_elastic_ip" "web" {
  zone        = var.zone
  description = "${var.name_prefix} web public IP"

  healthcheck {
    mode         = "tcp"
    port         = 80
    interval     = 10
    timeout      = 3
    strikes_ok   = 2
    strikes_fail = 3
  }
}

# Web compute instance
resource "exoscale_compute_instance" "web" {
  zone = var.zone
  name = "${var.name_prefix}-web"

  type        = var.instance_type_web
  template_id = data.exoscale_template.jambonz_web.id
  disk_size   = var.disk_size_web
  ssh_keys    = local.ssh_keys

  elastic_ip_ids = [exoscale_elastic_ip.web.id]

  network_interface {
    network_id = exoscale_private_network.jambonz.id
  }

  security_group_ids = [
    exoscale_security_group.ssh.id,
    exoscale_security_group.web.id,
    exoscale_security_group.internal.id
  ]

  # Depends on monitoring server being created first (needs its private IP)
  depends_on = [exoscale_compute_instance.monitoring]

  user_data = templatefile("${path.module}/cloud-init-web.yaml", {
    mysql_host               = data.exoscale_database_uri.mysql.host
    mysql_port               = data.exoscale_database_uri.mysql.port
    mysql_user               = data.exoscale_database_uri.mysql.username
    mysql_password           = data.exoscale_database_uri.mysql.password
    mysql_database           = data.exoscale_database_uri.mysql.db_name
    redis_host               = local.monitoring_private_ip
    redis_port               = 6379
    jwt_secret               = random_password.encryption_secret.result
    url_portal               = var.url_portal
    vpc_cidr                 = var.vpc_cidr
    monitoring_private_ip    = local.monitoring_private_ip
    deploy_recording_cluster = var.deploy_recording_cluster
    ssh_public_key           = local.ssh_public_key
  })

  labels = {
    role    = "web"
    cluster = var.name_prefix
  }
}

# =============================================================================
# RTP Servers
# =============================================================================

# Elastic IPs for RTP servers
resource "exoscale_elastic_ip" "rtp" {
  count       = var.rtp_count
  zone        = var.zone
  description = "${var.name_prefix} RTP ${count.index + 1} public IP"

  healthcheck {
    mode         = "tcp"
    port         = 22222
    interval     = 10
    timeout      = 3
    strikes_ok   = 2
    strikes_fail = 3
  }
}

# RTP compute instances
resource "exoscale_compute_instance" "rtp" {
  count = var.rtp_count
  zone  = var.zone
  name  = "${var.name_prefix}-rtp-${count.index + 1}"

  type        = var.instance_type_rtp
  template_id = data.exoscale_template.jambonz_rtp.id
  disk_size   = var.disk_size_rtp
  ssh_keys    = local.ssh_keys

  elastic_ip_ids = [exoscale_elastic_ip.rtp[count.index].id]

  network_interface {
    network_id = exoscale_private_network.jambonz.id
  }

  security_group_ids = [
    exoscale_security_group.ssh.id,
    exoscale_security_group.rtp.id,
    exoscale_security_group.internal.id
  ]

  # Depends on monitoring server (telegraf needs monitoring IP)
  depends_on = [exoscale_compute_instance.monitoring]

  user_data = templatefile("${path.module}/cloud-init-rtp.yaml", {
    vpc_cidr              = var.vpc_cidr
    monitoring_private_ip = local.monitoring_private_ip
    enable_pcaps          = var.enable_pcaps
    redis_host            = local.monitoring_private_ip
    redis_port            = 6379
    ssh_public_key        = local.ssh_public_key
  })

  labels = {
    role    = "rtp"
    cluster = var.name_prefix
    index   = tostring(count.index + 1)
  }
}

# =============================================================================
# SIP Servers
# =============================================================================

# Elastic IPs for SIP servers
resource "exoscale_elastic_ip" "sip" {
  count       = var.sip_count
  zone        = var.zone
  description = "${var.name_prefix} SIP ${count.index + 1} public IP"

  healthcheck {
    mode         = "tcp"
    port         = 5060
    interval     = 10
    timeout      = 3
    strikes_ok   = 2
    strikes_fail = 3
  }
}

# SIP compute instances
resource "exoscale_compute_instance" "sip" {
  count = var.sip_count
  zone  = var.zone
  name  = "${var.name_prefix}-sip-${count.index + 1}"

  type        = var.instance_type_sip
  template_id = data.exoscale_template.jambonz_sip.id
  disk_size   = var.disk_size_sip
  ssh_keys    = local.ssh_keys

  elastic_ip_ids = [exoscale_elastic_ip.sip[count.index].id]

  network_interface {
    network_id = exoscale_private_network.jambonz.id
  }

  security_group_ids = [
    exoscale_security_group.ssh.id,
    exoscale_security_group.sip.id,
    exoscale_security_group.internal.id
  ]

  # Depends on RTP servers (needs their private IPs for RTPENGINES env var)
  depends_on = [exoscale_compute_instance.rtp]

  user_data = templatefile("${path.module}/cloud-init-sip.yaml", {
    mysql_host            = data.exoscale_database_uri.mysql.host
    mysql_port            = data.exoscale_database_uri.mysql.port
    mysql_user            = data.exoscale_database_uri.mysql.username
    mysql_password        = data.exoscale_database_uri.mysql.password
    mysql_database        = data.exoscale_database_uri.mysql.db_name
    redis_host            = local.monitoring_private_ip
    redis_port            = 6379
    jwt_secret            = random_password.encryption_secret.result
    url_portal            = var.url_portal
    vpc_cidr              = var.vpc_cidr
    sip_index             = count.index + 1
    monitoring_private_ip = local.monitoring_private_ip
    enable_pcaps          = var.enable_pcaps
    rtp_private_ips       = join(",", [for rtp in exoscale_compute_instance.rtp : one(rtp.network_interface).ip_address])
    ssh_public_key        = local.ssh_public_key
    apiban_key            = var.apiban_key
    apiban_client_id      = var.apiban_client_id
    apiban_client_secret  = var.apiban_client_secret
  })

  labels = {
    role    = "sip"
    cluster = var.name_prefix
    index   = tostring(count.index + 1)
  }
}

# =============================================================================
# Feature Server Instance Pool
# =============================================================================

resource "exoscale_instance_pool" "feature_server" {
  zone = var.zone
  name = "${var.name_prefix}-feature-server-pool"

  template_id   = data.exoscale_template.jambonz_fs.id
  size          = var.feature_server_count
  instance_type = var.instance_type_feature
  disk_size     = var.disk_size_feature
  key_pair      = local.ssh_key

  network_ids = [exoscale_private_network.jambonz.id]

  security_group_ids = [
    exoscale_security_group.ssh.id,
    exoscale_security_group.feature_server.id,
    exoscale_security_group.internal.id
  ]

  # Depends on monitoring and recording (needs their IPs)
  depends_on = [exoscale_compute_instance.monitoring]

  user_data = templatefile("${path.module}/cloud-init-feature-server.yaml", {
    mysql_host               = data.exoscale_database_uri.mysql.host
    mysql_port               = data.exoscale_database_uri.mysql.port
    mysql_user               = data.exoscale_database_uri.mysql.username
    mysql_password           = data.exoscale_database_uri.mysql.password
    mysql_database           = data.exoscale_database_uri.mysql.db_name
    redis_host               = local.monitoring_private_ip
    redis_port               = 6379
    jwt_secret               = random_password.encryption_secret.result
    url_portal               = var.url_portal
    vpc_cidr                 = var.vpc_cidr
    monitoring_private_ip    = local.monitoring_private_ip
    recording_ws_base_url    = var.deploy_recording_cluster ? "ws://${exoscale_nlb.recording[0].ip_address}" : ""
    scale_in_timeout_seconds = var.scale_in_timeout_seconds
  })

  labels = {
    role    = "feature-server"
    cluster = var.name_prefix
  }
}

# =============================================================================
# Recording Server Instance Pool (Optional)
# =============================================================================

resource "exoscale_instance_pool" "recording" {
  count = var.deploy_recording_cluster ? 1 : 0

  zone = var.zone
  name = "${var.name_prefix}-recording-pool"

  template_id   = data.exoscale_template.jambonz_recording.id
  size          = var.recording_server_count
  instance_type = var.instance_type_recording
  disk_size     = var.disk_size_recording
  key_pair      = local.ssh_key

  network_ids = [exoscale_private_network.jambonz.id]

  security_group_ids = [
    exoscale_security_group.ssh.id,
    exoscale_security_group.recording.id,
    exoscale_security_group.internal.id
  ]

  user_data = templatefile("${path.module}/cloud-init-recording.yaml", {
    mysql_host     = data.exoscale_database_uri.mysql.host
    mysql_port     = data.exoscale_database_uri.mysql.port
    mysql_user     = data.exoscale_database_uri.mysql.username
    mysql_password = data.exoscale_database_uri.mysql.password
    mysql_database = data.exoscale_database_uri.mysql.db_name
    redis_host     = local.monitoring_private_ip
    redis_port     = 6379
    jwt_secret     = random_password.encryption_secret.result
    url_portal     = var.url_portal
    vpc_cidr       = var.vpc_cidr
  })

  labels = {
    role    = "recording"
    cluster = var.name_prefix
  }
}
