# Outputs for jambonz large cluster deployment on OCI

output "portal_url" {
  description = "URL for the jambonz portal"
  value       = "http://${var.url_portal}"
}

output "api_url" {
  description = "URL for the jambonz API"
  value       = "http://${var.url_portal}/api/v1"
}

output "grafana_url" {
  description = "URL for the Grafana portal"
  value       = "http://grafana.${var.url_portal}"
}

output "homer_url" {
  description = "URL for the Homer portal"
  value       = "http://homer.${var.url_portal}"
}

output "web_public_ip" {
  description = "Public IP address of the Web server - create DNS A records pointing to this IP"
  value       = oci_core_instance.web.public_ip
}

output "web_private_ip" {
  description = "Private IP address of the Web server"
  value       = oci_core_instance.web.private_ip
}

output "monitoring_public_ip" {
  description = "Public IP address of the Monitoring server"
  value       = oci_core_instance.monitoring.public_ip
}

output "monitoring_private_ip" {
  description = "Private IP address of the Monitoring server (Redis, Grafana, Homer, Jaeger)"
  value       = oci_core_instance.monitoring.private_ip
}

output "sip_public_ips" {
  description = "Reserved public IP addresses for SIP instances - these persist across instance recreation"
  value       = oci_core_public_ip.sip[*].ip_address
}

output "sip_private_ips" {
  description = "Private IP addresses for SIP instances"
  value       = oci_core_instance.sip[*].private_ip
}

output "rtp_public_ips" {
  description = "Reserved public IP addresses for RTP instances - these persist across instance recreation"
  value       = oci_core_public_ip.rtp[*].ip_address
}

output "rtp_private_ips" {
  description = "Private IP addresses for RTP instances"
  value       = oci_core_instance.rtp[*].private_ip
}

output "feature_server_public_ips" {
  description = "Public IP addresses for Feature Server instances"
  value       = oci_core_instance.feature_server[*].public_ip
}

output "feature_server_private_ips" {
  description = "Private IP addresses for Feature Server instances"
  value       = oci_core_instance.feature_server[*].private_ip
}

output "recording_private_ips" {
  description = "Private IP addresses for Recording Server instances (if deployed)"
  value       = var.deploy_recording_cluster ? oci_core_instance.recording[*].private_ip : []
}

output "compartment_id" {
  description = "OCI compartment ID"
  value       = var.compartment_id
}

output "vcn_id" {
  description = "Virtual Cloud Network ID"
  value       = oci_core_vcn.jambonz.id
}

output "web_instance_id" {
  description = "Web instance OCID"
  value       = oci_core_instance.web.id
}

output "monitoring_instance_id" {
  description = "Monitoring instance OCID"
  value       = oci_core_instance.monitoring.id
}

output "sip_instance_ids" {
  description = "SIP instance OCIDs"
  value       = oci_core_instance.sip[*].id
}

output "rtp_instance_ids" {
  description = "RTP instance OCIDs"
  value       = oci_core_instance.rtp[*].id
}

output "feature_server_instance_ids" {
  description = "Feature Server instance OCIDs"
  value       = oci_core_instance.feature_server[*].id
}

output "recording_instance_ids" {
  description = "Recording Server instance OCIDs (if deployed)"
  value       = var.deploy_recording_cluster ? oci_core_instance.recording[*].id : []
}

output "mysql_endpoint" {
  description = "MySQL HeatWave endpoint"
  value       = oci_mysql_mysql_db_system.jambonz.ip_address
}

output "mysql_port" {
  description = "MySQL HeatWave port"
  value       = oci_mysql_mysql_db_system.jambonz.port
}

output "redis_endpoint" {
  description = "Redis endpoint (on monitoring server)"
  value       = oci_core_instance.monitoring.private_ip
}

output "redis_port" {
  description = "Redis port"
  value       = 6379
}

output "portal_username" {
  description = "Login username for the jambonz portal"
  value       = "admin"
}

output "portal_password" {
  description = "Initial password for jambonz portal (you will be forced to change it on first login)"
  value       = oci_core_instance.web.id
  sensitive   = true
}

output "grafana_username" {
  description = "Login username for the Grafana portal"
  value       = "admin"
}

output "grafana_password" {
  description = "Initial password for Grafana portal"
  value       = "admin"
}

output "ssh_connection_web" {
  description = "SSH connection command for Web server"
  value       = "ssh jambonz@${oci_core_instance.web.public_ip}"
}

output "ssh_connection_monitoring" {
  description = "SSH connection command for Monitoring server"
  value       = "ssh jambonz@${oci_core_instance.monitoring.public_ip}"
}

output "ssh_connection_sip" {
  description = "SSH connection commands for SIP instances"
  value       = [for i, ip in oci_core_public_ip.sip[*].ip_address : "ssh jambonz@${ip}"]
}

output "ssh_connection_rtp" {
  description = "SSH connection commands for RTP instances"
  value       = [for i, ip in oci_core_public_ip.rtp[*].ip_address : "ssh jambonz@${ip}"]
}

output "ssh_connection_feature_server" {
  description = "SSH connection commands for Feature Server instances"
  value       = [for i, ip in oci_core_instance.feature_server[*].public_ip : "ssh jambonz@${ip}"]
}

output "dns_records_required" {
  description = "DNS A records that need to be created"
  value = {
    "${var.url_portal}"             = oci_core_instance.web.public_ip
    "api.${var.url_portal}"         = oci_core_instance.web.public_ip
    "grafana.${var.url_portal}"     = oci_core_instance.web.public_ip
    "homer.${var.url_portal}"       = oci_core_instance.web.public_ip
    "public-apps.${var.url_portal}" = oci_core_instance.web.public_ip
    "sip.${var.url_portal}"         = oci_core_public_ip.sip[0].ip_address
  }
}

output "recording_lb_ip" {
  description = "Recording Server Load Balancer IP (if deployed)"
  value       = var.deploy_recording_cluster ? [for ip in oci_network_load_balancer_network_load_balancer.recording[0].ip_addresses : ip.ip_address if ip.is_public == false][0] : "Not deployed"
}

output "image_ocids" {
  description = "Image OCIDs imported into this tenancy"
  value = {
    sip            = oci_core_image.sip.id
    rtp            = oci_core_image.rtp.id
    web            = oci_core_image.web.id
    monitoring     = oci_core_image.monitoring.id
    feature_server = oci_core_image.feature_server.id
    recording      = var.deploy_recording_cluster ? oci_core_image.recording[0].id : "Not deployed"
  }
}
