# Image import from PAR URL for jambonz mini on OCI
#
# This imports the jambonz image from a Pre-Authenticated Request (PAR) URL
# into the user's compartment. The import happens once on first apply and
# takes approximately 5-15 minutes depending on image size.

resource "oci_core_image" "jambonz_mini" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-jambonz-mini"

  image_source_details {
    source_type = "objectStorageUri"
    source_uri  = var.image_par_url
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    deployment  = "mini"
  }

  timeouts {
    create = "30m"
  }
}
