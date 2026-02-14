# Image imports from PAR URLs for jambonz large cluster on OCI
#
# Large deployment uses separate images for SIP, RTP, Web, and Monitoring
# (unlike medium which uses combined SBC and web-monitoring images)

# ------------------------------------------------------------------------------
# SIP IMAGE (drachtio only)
# ------------------------------------------------------------------------------

resource "oci_core_image" "sip" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-jambonz-sip"

  image_source_details {
    source_type = "objectStorageUri"
    source_uri  = var.sip_image_par_url
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "sip"
  }

  timeouts {
    create = "30m"
  }
}

# ------------------------------------------------------------------------------
# RTP IMAGE (rtpengine only)
# ------------------------------------------------------------------------------

resource "oci_core_image" "rtp" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-jambonz-rtp"

  image_source_details {
    source_type = "objectStorageUri"
    source_uri  = var.rtp_image_par_url
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "rtp"
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
# WEB IMAGE (portal, API, webapp)
# ------------------------------------------------------------------------------

resource "oci_core_image" "web" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-jambonz-web"

  image_source_details {
    source_type = "objectStorageUri"
    source_uri  = var.web_image_par_url
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "web"
  }

  timeouts {
    create = "30m"
  }
}

# ------------------------------------------------------------------------------
# MONITORING IMAGE (Grafana, Homer, Jaeger, InfluxDB)
# ------------------------------------------------------------------------------

resource "oci_core_image" "monitoring" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-jambonz-monitoring"

  image_source_details {
    source_type = "objectStorageUri"
    source_uri  = var.monitoring_image_par_url
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    role        = "monitoring"
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
