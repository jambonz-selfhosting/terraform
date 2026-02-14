# Compute instance for jambonz mini on OCI

resource "oci_core_instance" "jambonz_mini" {
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.shape
  display_name        = "${var.name_prefix}-jambonz-mini"

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = oci_core_image.jambonz_mini.id
    boot_volume_size_in_gbs = var.disk_size
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public.id
    assign_public_ip          = false
    display_name              = "${var.name_prefix}-vnic"
    hostname_label            = "jambonz"
    nsg_ids                   = [oci_core_network_security_group.jambonz.id]
    skip_source_dest_check    = false
    assign_private_dns_record = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(templatefile("${path.module}/cloud-init.yaml", {
      url_portal           = var.url_portal
      jwt_secret           = random_password.jwt_secret.result
      db_password          = random_password.db_password.result
      instance_name        = "${var.name_prefix}-jambonz-mini"
      apiban_key           = var.apiban_key
      apiban_client_id     = var.apiban_client_id
      apiban_client_secret = var.apiban_client_secret
    }))
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    deployment  = "mini"
  }
}

# ------------------------------------------------------------------------------
# RESERVED PUBLIC IP
# Static IP that persists even if the instance is recreated
# ------------------------------------------------------------------------------

data "oci_core_vnic_attachments" "jambonz_mini" {
  compartment_id = var.compartment_id
  instance_id    = oci_core_instance.jambonz_mini.id
}

data "oci_core_private_ips" "jambonz_mini" {
  vnic_id = data.oci_core_vnic_attachments.jambonz_mini.vnic_attachments[0].vnic_id
}

resource "oci_core_public_ip" "jambonz_mini" {
  compartment_id = var.compartment_id
  lifetime       = "RESERVED"
  display_name   = "${var.name_prefix}-jambonz-mini-ip"
  private_ip_id  = data.oci_core_private_ips.jambonz_mini.private_ips[0].id

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    deployment  = "mini"
  }
}
