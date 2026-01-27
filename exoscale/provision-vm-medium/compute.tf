# =============================================================================
# Template ID Lookup
# =============================================================================
# Note: Exoscale provider does not have a data source for templates.
# You must provide template IDs (not names) in terraform.tfvars.
# Use: exo compute template list --zone ch-gva-2 --visibility private
# to get the template IDs.

# =============================================================================
# Web/Monitoring Server
# =============================================================================

# Elastic IP for web/monitoring server
resource "exoscale_elastic_ip" "web_monitoring" {
  zone        = var.zone
  description = "${var.name_prefix} web/monitoring public IP"

  healthcheck {
    mode         = "tcp"
    port         = 80
    interval     = 10
    timeout      = 3
    strikes_ok   = 2
    strikes_fail = 3
  }
}

# Web/Monitoring compute instance
resource "exoscale_compute_instance" "web_monitoring" {
  zone = var.zone
  name = "${var.name_prefix}-web-monitoring"

  type        = var.instance_type_web
  template_id = var.template_web_monitoring
  disk_size   = var.disk_size_web
  ssh_keys    = local.ssh_keys

  elastic_ip_ids = [exoscale_elastic_ip.web_monitoring.id]

  network_interface {
    network_id = exoscale_private_network.jambonz.id
  }

  security_group_ids = [
    exoscale_security_group.ssh.id,
    exoscale_security_group.web_monitoring.id,
    exoscale_security_group.internal.id
  ]

  user_data = templatefile("${path.module}/cloud-init-web-monitoring.yaml", {
    mysql_host               = data.exoscale_database_uri.mysql.host
    mysql_port               = data.exoscale_database_uri.mysql.port
    mysql_user               = data.exoscale_database_uri.mysql.username
    mysql_password           = data.exoscale_database_uri.mysql.password
    mysql_database           = data.exoscale_database_uri.mysql.db_name
    redis_host               = data.exoscale_database_uri.valkey.host
    redis_port               = data.exoscale_database_uri.valkey.port
    jwt_secret               = random_password.encryption_secret.result
    url_portal               = var.url_portal
    vpc_cidr                 = var.vpc_cidr
    deploy_recording_cluster = var.deploy_recording_cluster
    apiban_key               = var.apiban_key
    ssh_public_key           = local.ssh_public_key
  })

  labels = {
    role    = "web-monitoring"
    cluster = var.name_prefix
  }
}

# =============================================================================
# SBC Servers
# =============================================================================

# Elastic IPs for SBC servers
resource "exoscale_elastic_ip" "sbc" {
  count       = var.sbc_count
  zone        = var.zone
  description = "${var.name_prefix} SBC ${count.index + 1} public IP"

  healthcheck {
    mode         = "tcp"
    port         = 5060
    interval     = 10
    timeout      = 3
    strikes_ok   = 2
    strikes_fail = 3
  }
}

# SBC compute instances
resource "exoscale_compute_instance" "sbc" {
  count = var.sbc_count
  zone  = var.zone
  name  = "${var.name_prefix}-sbc-${count.index + 1}"

  type        = var.instance_type_sbc
  template_id = var.template_sbc
  disk_size   = var.disk_size_sbc
  ssh_keys    = local.ssh_keys

  elastic_ip_ids = [exoscale_elastic_ip.sbc[count.index].id]

  network_interface {
    network_id = exoscale_private_network.jambonz.id
  }

  security_group_ids = [
    exoscale_security_group.ssh.id,
    exoscale_security_group.sbc.id,
    exoscale_security_group.internal.id
  ]

  user_data = templatefile("${path.module}/cloud-init-sbc.yaml", {
    mysql_host           = data.exoscale_database_uri.mysql.host
    mysql_port           = data.exoscale_database_uri.mysql.port
    mysql_user           = data.exoscale_database_uri.mysql.username
    mysql_password       = data.exoscale_database_uri.mysql.password
    mysql_database       = data.exoscale_database_uri.mysql.db_name
    redis_host           = data.exoscale_database_uri.valkey.host
    redis_port           = data.exoscale_database_uri.valkey.port
    jwt_secret           = random_password.encryption_secret.result
    url_portal           = var.url_portal
    vpc_cidr             = var.vpc_cidr
    sbc_index            = count.index + 1
    ssh_public_key       = local.ssh_public_key
    apiban_key           = var.apiban_key
    apiban_client_id     = var.apiban_client_id
    apiban_client_secret = var.apiban_client_secret
  })

  labels = {
    role    = "sbc"
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

  template_id   = var.template_feature_server
  size          = var.feature_server_count
  instance_type = var.instance_type_feature
  disk_size     = var.disk_size_feature
  key_pair      = local.ssh_key

  # NOTE: Instance pool members get public IPv4 addresses by default in Exoscale
  # This is required for DBaaS connectivity as Exoscale DBaaS only accepts connections from public IPs
  # The public IPs are ephemeral (change on instance recreation) but fall within zone CIDR ranges

  network_ids = [exoscale_private_network.jambonz.id]

  security_group_ids = [
    exoscale_security_group.ssh.id,
    exoscale_security_group.feature_server.id,
    exoscale_security_group.internal.id
  ]

  user_data = templatefile("${path.module}/cloud-init-feature-server.yaml", {
    mysql_host               = data.exoscale_database_uri.mysql.host
    mysql_port               = data.exoscale_database_uri.mysql.port
    mysql_user               = data.exoscale_database_uri.mysql.username
    mysql_password           = data.exoscale_database_uri.mysql.password
    mysql_database           = data.exoscale_database_uri.mysql.db_name
    redis_host               = data.exoscale_database_uri.valkey.host
    redis_port               = data.exoscale_database_uri.valkey.port
    jwt_secret               = random_password.encryption_secret.result
    url_portal               = var.url_portal
    vpc_cidr                 = var.vpc_cidr
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

  template_id   = var.template_recording
  size          = var.recording_server_count
  instance_type = var.instance_type_recording
  disk_size     = var.disk_size_recording
  key_pair      = local.ssh_key

  # NOTE: Instance pool members get public IPv4 addresses by default in Exoscale
  # This is required for DBaaS connectivity as Exoscale DBaaS only accepts connections from public IPs
  # The public IPs are ephemeral (change on instance recreation) but fall within zone CIDR ranges

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
    redis_host     = data.exoscale_database_uri.valkey.host
    redis_port     = data.exoscale_database_uri.valkey.port
    jwt_secret     = random_password.encryption_secret.result
    url_portal     = var.url_portal
    vpc_cidr       = var.vpc_cidr
  })

  labels = {
    role    = "recording"
    cluster = var.name_prefix
  }
}
