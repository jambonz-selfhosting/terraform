# Compute instances for jambonz medium cluster on OCI

# ------------------------------------------------------------------------------
# WEB/MONITORING SERVER
# ------------------------------------------------------------------------------

resource "oci_core_instance" "web_monitoring" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.web_monitoring_shape
  display_name        = "${var.name_prefix}-web-monitoring"

  shape_config {
    ocpus         = var.web_monitoring_ocpus
    memory_in_gbs = var.web_monitoring_memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = oci_core_image.web_monitoring.id
    boot_volume_size_in_gbs = var.web_monitoring_disk_size
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public.id
    assign_public_ip          = true
    display_name              = "${var.name_prefix}-web-monitoring-vnic"
    hostname_label            = "webmon"
    nsg_ids                   = [oci_core_network_security_group.web_monitoring.id]
    skip_source_dest_check    = false
    assign_private_dns_record = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(templatefile("${path.module}/cloud-init-web-monitoring.yaml", {
      mysql_host               = oci_mysql_mysql_db_system.jambonz.endpoints[0].hostname
      mysql_user               = var.mysql_username
      mysql_password           = local.db_password
      redis_host               = oci_redis_redis_cluster.jambonz.primary_endpoint_ip_address
      redis_port               = 6379
      jwt_secret               = random_password.encryption_secret.result
      url_portal               = var.url_portal
      vpc_cidr                 = var.vcn_cidr
      deploy_recording_cluster = var.deploy_recording_cluster
    }))
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "web-monitoring"
  }

  depends_on = [
    oci_mysql_mysql_db_system.jambonz,
    oci_redis_redis_cluster.jambonz
  ]
}

# ------------------------------------------------------------------------------
# SBC SERVERS
# ------------------------------------------------------------------------------

resource "oci_core_instance" "sbc" {
  count = var.sbc_count

  availability_domain = local.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.sbc_shape
  display_name        = "${var.name_prefix}-sbc-${count.index}"

  shape_config {
    ocpus         = var.sbc_ocpus
    memory_in_gbs = var.sbc_memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = oci_core_image.sbc.id
    boot_volume_size_in_gbs = var.sbc_disk_size
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public.id
    assign_public_ip          = true
    display_name              = "${var.name_prefix}-sbc-${count.index}-vnic"
    hostname_label            = "sbc${count.index}"
    nsg_ids                   = [oci_core_network_security_group.sbc.id]
    skip_source_dest_check    = false
    assign_private_dns_record = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(templatefile("${path.module}/cloud-init-sbc.yaml", {
      mysql_host                = oci_mysql_mysql_db_system.jambonz.endpoints[0].hostname
      mysql_user                = var.mysql_username
      mysql_password            = local.db_password
      redis_host                = oci_redis_redis_cluster.jambonz.primary_endpoint_ip_address
      redis_port                = 6379
      jwt_secret                = random_password.encryption_secret.result
      web_monitoring_private_ip = oci_core_instance.web_monitoring.private_ip
      vpc_cidr                  = var.vcn_cidr
      enable_pcaps              = var.enable_pcaps
      apiban_key                = var.apiban_key
      apiban_client_id          = var.apiban_client_id
      apiban_client_secret      = var.apiban_client_secret
    }))
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "sbc"
  }

  depends_on = [oci_core_instance.web_monitoring]
}

# ------------------------------------------------------------------------------
# FEATURE SERVERS
# ------------------------------------------------------------------------------

resource "oci_core_instance" "feature_server" {
  count = var.feature_server_count

  availability_domain = local.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.feature_server_shape
  display_name        = "${var.name_prefix}-fs-${count.index}"

  shape_config {
    ocpus         = var.feature_server_ocpus
    memory_in_gbs = var.feature_server_memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = oci_core_image.feature_server.id
    boot_volume_size_in_gbs = var.feature_server_disk_size
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public.id
    assign_public_ip          = true
    display_name              = "${var.name_prefix}-fs-${count.index}-vnic"
    hostname_label            = "fs${count.index}"
    nsg_ids                   = [oci_core_network_security_group.feature_server.id]
    skip_source_dest_check    = false
    assign_private_dns_record = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(templatefile("${path.module}/cloud-init-feature-server.yaml", {
      mysql_host                = oci_mysql_mysql_db_system.jambonz.endpoints[0].hostname
      mysql_user                = var.mysql_username
      mysql_password            = local.db_password
      redis_host                = oci_redis_redis_cluster.jambonz.primary_endpoint_ip_address
      redis_port                = 6379
      jwt_secret                = random_password.encryption_secret.result
      web_monitoring_private_ip = oci_core_instance.web_monitoring.private_ip
      vpc_cidr                  = var.vcn_cidr
      url_portal                = var.url_portal
      recording_ws_base_url     = var.deploy_recording_cluster && length(oci_core_instance.recording) > 0 ? "ws://${oci_core_instance.recording[0].private_ip}:3000" : "ws://${oci_core_instance.web_monitoring.private_ip}:3017"
    }))
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "feature-server"
  }

  depends_on = [oci_core_instance.web_monitoring]
}

# ------------------------------------------------------------------------------
# RECORDING SERVERS (conditional)
# ------------------------------------------------------------------------------

resource "oci_core_instance" "recording" {
  count = var.deploy_recording_cluster ? var.recording_count : 0

  availability_domain = local.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.recording_shape
  display_name        = "${var.name_prefix}-recording-${count.index}"

  shape_config {
    ocpus         = var.recording_ocpus
    memory_in_gbs = var.recording_memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = oci_core_image.recording[0].id
    boot_volume_size_in_gbs = var.recording_disk_size
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public.id
    assign_public_ip          = false
    display_name              = "${var.name_prefix}-recording-${count.index}-vnic"
    hostname_label            = "recording${count.index}"
    nsg_ids                   = [oci_core_network_security_group.recording[0].id]
    skip_source_dest_check    = false
    assign_private_dns_record = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(templatefile("${path.module}/cloud-init-recording.yaml", {
      mysql_host                = oci_mysql_mysql_db_system.jambonz.endpoints[0].hostname
      mysql_user                = var.mysql_username
      mysql_password            = local.db_password
      jwt_secret                = random_password.encryption_secret.result
      web_monitoring_private_ip = oci_core_instance.web_monitoring.private_ip
    }))
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "recording"
  }

  depends_on = [oci_core_instance.web_monitoring]
}
