# Image imports from PAR URLs for jambonz medium cluster on OCI
#
# These import the jambonz images from Pre-Authenticated Request (PAR) URLs
# into the user's compartment. The import happens once on first apply and
# takes approximately 5-15 minutes per image.

# ------------------------------------------------------------------------------
# SBC IMAGE (drachtio + rtpengine)
# ------------------------------------------------------------------------------

resource "oci_core_image" "sbc" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-jambonz-sbc"

  image_source_details {
    source_type = "objectStorageUri"
    source_uri  = var.sbc_image_par_url
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "sbc"
  }

  timeouts {
    create = "30m"
  }
}

# ------------------------------------------------------------------------------
# FEATURE SERVER IMAGE (FreeSWITCH)
# ------------------------------------------------------------------------------

resource "oci_core_image" "feature_server" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-jambonz-feature-server"

  image_source_details {
    source_type = "objectStorageUri"
    source_uri  = var.feature_server_image_par_url
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "feature-server"
  }

  timeouts {
    create = "30m"
  }
}

# ------------------------------------------------------------------------------
# WEB/MONITORING IMAGE (portal, API, Grafana, Homer, Jaeger)
# ------------------------------------------------------------------------------

resource "oci_core_image" "web_monitoring" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-jambonz-web-monitoring"

  image_source_details {
    source_type = "objectStorageUri"
    source_uri  = var.web_monitoring_image_par_url
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "web-monitoring"
  }

  timeouts {
    create = "30m"
  }
}

# ------------------------------------------------------------------------------
# RECORDING IMAGE (optional)
# ------------------------------------------------------------------------------

resource "oci_core_image" "recording" {
  count = var.deploy_recording_cluster && var.recording_image_par_url != "" ? 1 : 0

  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-jambonz-recording"

  image_source_details {
    source_type = "objectStorageUri"
    source_uri  = var.recording_image_par_url
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "recording"
  }

  timeouts {
    create = "30m"
  }
}
