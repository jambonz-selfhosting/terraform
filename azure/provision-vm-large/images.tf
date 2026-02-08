# ------------------------------------------------------------------------------
# COMMUNITY GALLERY IMAGES
# Images are published to the jambonz Azure Community Gallery
# Community Gallery image IDs use format: /communityGalleries/{gallery}/images/{image}/versions/{version}
#
# Large deployment has 6 image types:
# - Web (portal/API)
# - Monitoring (Grafana/Homer/Jaeger)
# - SIP (drachtio signaling)
# - RTP (rtpengine media)
# - Feature Server (FreeSWITCH)
# - Recording (optional)
# ------------------------------------------------------------------------------

locals {
  web_image_id            = "/communityGalleries/${var.community_gallery_name}/images/jambonz-web/versions/${var.jambonz_version}"
  monitoring_image_id     = "/communityGalleries/${var.community_gallery_name}/images/jambonz-monitoring/versions/${var.jambonz_version}"
  sip_image_id            = "/communityGalleries/${var.community_gallery_name}/images/jambonz-sip/versions/${var.jambonz_version}"
  rtp_image_id            = "/communityGalleries/${var.community_gallery_name}/images/jambonz-rtp/versions/${var.jambonz_version}"
  feature_server_image_id = "/communityGalleries/${var.community_gallery_name}/images/jambonz-fs/versions/${var.jambonz_version}"
  recording_image_id      = var.deploy_recording_cluster ? "/communityGalleries/${var.community_gallery_name}/images/jambonz-recording/versions/${var.jambonz_version}" : ""
}
