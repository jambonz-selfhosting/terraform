# ------------------------------------------------------------------------------
# COMMUNITY GALLERY IMAGES
# Images are published to the jambonz Azure Community Gallery
# Community Gallery image IDs use format: /communityGalleries/{gallery}/images/{image}/versions/{version}
#
# Medium deployment uses 4 image types:
# - SBC (drachtio + rtpengine combined)
# - Feature Server (FreeSWITCH)
# - Web/Monitoring (portal, API, Grafana, Homer, Jaeger)
# - Recording (optional)
# ------------------------------------------------------------------------------

locals {
  sbc_image_id            = "/communityGalleries/${var.community_gallery_name}/images/jambonz-sip-rtp/versions/${var.jambonz_version}"
  feature_server_image_id = "/communityGalleries/${var.community_gallery_name}/images/jambonz-fs/versions/${var.jambonz_version}"
  web_monitoring_image_id = "/communityGalleries/${var.community_gallery_name}/images/jambonz-web-monitoring/versions/${var.jambonz_version}"
  recording_image_id      = var.deploy_recording_cluster ? "/communityGalleries/${var.community_gallery_name}/images/jambonz-recording/versions/${var.jambonz_version}" : ""
}
