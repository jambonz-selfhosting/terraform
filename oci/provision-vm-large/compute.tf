# Compute instances for jambonz large cluster on OCI
# Fully separated architecture: Web, Monitoring, SIP, RTP as individual VMs

# ------------------------------------------------------------------------------
# MONITORING SERVER
# Must come up first - provides Redis, InfluxDB, Grafana, Homer, Jaeger
# ------------------------------------------------------------------------------

resource "oci_core_instance" "monitoring" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.monitoring_shape
  display_name        = "${var.name_prefix}-monitoring"

  shape_config {
    ocpus         = var.monitoring_ocpus
    memory_in_gbs = var.monitoring_memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = oci_core_image.monitoring.id
    boot_volume_size_in_gbs = var.monitoring_disk_size
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public.id
    assign_public_ip          = true
    display_name              = "${var.name_prefix}-monitoring-vnic"
    hostname_label            = "monitoring"
    nsg_ids                   = [oci_core_network_security_group.monitoring.id]
    skip_source_dest_check    = false
    assign_private_dns_record = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(templatefile("${path.module}/cloud-init-monitoring.yaml", {
      url_portal = var.url_portal
      vpc_cidr   = var.vcn_cidr
    }))
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "monitoring"
  }

  depends_on = [
    oci_mysql_mysql_db_system.jambonz
  ]
}

# ------------------------------------------------------------------------------
# WEB SERVER
# Portal, API, webapp - depends on monitoring for Jaeger/Homer/Grafana proxying
# ------------------------------------------------------------------------------

resource "oci_core_instance" "web" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.web_shape
  display_name        = "${var.name_prefix}-web"

  shape_config {
    ocpus         = var.web_ocpus
    memory_in_gbs = var.web_memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = oci_core_image.web.id
    boot_volume_size_in_gbs = var.web_disk_size
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public.id
    assign_public_ip          = true
    display_name              = "${var.name_prefix}-web-vnic"
    hostname_label            = "web"
    nsg_ids                   = [oci_core_network_security_group.web.id]
    skip_source_dest_check    = false
    assign_private_dns_record = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(templatefile("${path.module}/cloud-init-web.yaml", {
      mysql_host               = oci_mysql_mysql_db_system.jambonz.ip_address
      mysql_user               = var.mysql_username
      mysql_password           = local.db_password
      redis_host               = oci_core_instance.monitoring.private_ip
      redis_port               = 6379
      jwt_secret               = random_password.encryption_secret.result
      url_portal               = var.url_portal
      vpc_cidr                 = var.vcn_cidr
      monitoring_private_ip    = oci_core_instance.monitoring.private_ip
      deploy_recording_cluster = var.deploy_recording_cluster
    }))
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "web"
  }

  depends_on = [
    oci_mysql_mysql_db_system.jambonz,
    oci_core_instance.monitoring
  ]
}

# ------------------------------------------------------------------------------
# RTP SERVERS
# Must come up before SIP servers (SIP needs RTP IPs for RTPENGINES config)
# ------------------------------------------------------------------------------

resource "oci_core_instance" "rtp" {
  count = var.rtp_count

  availability_domain = local.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.rtp_shape
  display_name        = "${var.name_prefix}-rtp-${count.index}"

  shape_config {
    ocpus         = var.rtp_ocpus
    memory_in_gbs = var.rtp_memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = oci_core_image.rtp.id
    boot_volume_size_in_gbs = var.rtp_disk_size
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public.id
    assign_public_ip          = false
    display_name              = "${var.name_prefix}-rtp-${count.index}-vnic"
    hostname_label            = "rtp${count.index}"
    nsg_ids                   = [oci_core_network_security_group.rtp.id]
    skip_source_dest_check    = false
    assign_private_dns_record = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(templatefile("${path.module}/cloud-init-rtp.yaml", {
      monitoring_private_ip = oci_core_instance.monitoring.private_ip
      vpc_cidr              = var.vcn_cidr
      enable_pcaps          = var.enable_pcaps
    }))
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "rtp"
  }

  depends_on = [oci_core_instance.monitoring]
}

# Reserved public IPs for RTP servers (static IPs for media traffic)
data "oci_core_vnic_attachments" "rtp" {
  count          = var.rtp_count
  compartment_id = var.compartment_id
  instance_id    = oci_core_instance.rtp[count.index].id
}

data "oci_core_private_ips" "rtp" {
  count   = var.rtp_count
  vnic_id = data.oci_core_vnic_attachments.rtp[count.index].vnic_attachments[0].vnic_id
}

resource "oci_core_public_ip" "rtp" {
  count          = var.rtp_count
  compartment_id = var.compartment_id
  lifetime       = "RESERVED"
  display_name   = "${var.name_prefix}-rtp-${count.index}-ip"
  private_ip_id  = data.oci_core_private_ips.rtp[count.index].private_ips[0].id

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "rtp"
  }
}

# ------------------------------------------------------------------------------
# SIP SERVERS
# Depends on RTP servers being up (needs their private IPs)
# ------------------------------------------------------------------------------

resource "oci_core_instance" "sip" {
  count = var.sip_count

  availability_domain = local.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.sip_shape
  display_name        = "${var.name_prefix}-sip-${count.index}"

  shape_config {
    ocpus         = var.sip_ocpus
    memory_in_gbs = var.sip_memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = oci_core_image.sip.id
    boot_volume_size_in_gbs = var.sip_disk_size
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public.id
    assign_public_ip          = false
    display_name              = "${var.name_prefix}-sip-${count.index}-vnic"
    hostname_label            = "sip${count.index}"
    nsg_ids                   = [oci_core_network_security_group.sip.id]
    skip_source_dest_check    = false
    assign_private_dns_record = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(templatefile("${path.module}/cloud-init-sip.yaml", {
      mysql_host            = oci_mysql_mysql_db_system.jambonz.ip_address
      mysql_user            = var.mysql_username
      mysql_password        = local.db_password
      redis_host            = oci_core_instance.monitoring.private_ip
      redis_port            = 6379
      jwt_secret            = random_password.encryption_secret.result
      monitoring_private_ip = oci_core_instance.monitoring.private_ip
      vpc_cidr              = var.vcn_cidr
      enable_pcaps          = var.enable_pcaps
      apiban_key            = var.apiban_key
      apiban_client_id      = var.apiban_client_id
      apiban_client_secret  = var.apiban_client_secret
      rtp_private_ips       = join(",", oci_core_instance.rtp[*].private_ip)
    }))
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "sip"
  }

  depends_on = [
    oci_core_instance.monitoring,
    oci_core_instance.rtp
  ]
}

# Reserved public IPs for SIP servers (static IPs for SIP traffic)
data "oci_core_vnic_attachments" "sip" {
  count          = var.sip_count
  compartment_id = var.compartment_id
  instance_id    = oci_core_instance.sip[count.index].id
}

data "oci_core_private_ips" "sip" {
  count   = var.sip_count
  vnic_id = data.oci_core_vnic_attachments.sip[count.index].vnic_attachments[0].vnic_id
}

resource "oci_core_public_ip" "sip" {
  count          = var.sip_count
  compartment_id = var.compartment_id
  lifetime       = "RESERVED"
  display_name   = "${var.name_prefix}-sip-${count.index}-ip"
  private_ip_id  = data.oci_core_private_ips.sip[count.index].private_ips[0].id

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "sip"
  }
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
      mysql_host                = oci_mysql_mysql_db_system.jambonz.ip_address
      mysql_user                = var.mysql_username
      mysql_password            = local.db_password
      redis_host                = oci_core_instance.monitoring.private_ip
      redis_port                = 6379
      jwt_secret                = random_password.encryption_secret.result
      web_monitoring_private_ip = oci_core_instance.monitoring.private_ip
      vpc_cidr                  = var.vcn_cidr
      url_portal                = var.url_portal
      recording_ws_base_url     = var.deploy_recording_cluster && length(oci_core_instance.recording) > 0 ? "ws://${oci_core_instance.recording[0].private_ip}:3000" : "ws://${oci_core_instance.web.private_ip}:3017"
    }))
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "feature-server"
  }

  depends_on = [oci_core_instance.monitoring]
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
    subnet_id                 = oci_core_subnet.private.id
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
      mysql_host                = oci_mysql_mysql_db_system.jambonz.ip_address
      mysql_user                = var.mysql_username
      mysql_password            = local.db_password
      jwt_secret                = random_password.encryption_secret.result
      web_monitoring_private_ip = oci_core_instance.monitoring.private_ip
    }))
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "recording"
  }

  depends_on = [oci_core_instance.monitoring]
}
