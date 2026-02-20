# Outputs for jambonz large cluster deployment on AWS
# Fully separated architecture: Web, Monitoring, SIP, RTP as individual VMs

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

# ------------------------------------------------------------------------------
# WEB SERVER OUTPUTS
# ------------------------------------------------------------------------------

output "web_public_ip" {
  description = "Public IP address of the Web server - create DNS A records pointing to this IP"
  value       = aws_eip.web.public_ip
}

output "web_private_ip" {
  description = "Private IP address of the Web server"
  value       = aws_instance.web.private_ip
}

output "web_instance_id" {
  description = "Web EC2 instance ID"
  value       = aws_instance.web.id
}

# ------------------------------------------------------------------------------
# MONITORING SERVER OUTPUTS
# ------------------------------------------------------------------------------

output "monitoring_public_ip" {
  description = "Public IP address of the Monitoring server - create DNS A records pointing to this IP"
  value       = aws_eip.monitoring.public_ip
}

output "monitoring_private_ip" {
  description = "Private IP address of the Monitoring server"
  value       = aws_instance.monitoring.private_ip
}

output "monitoring_instance_id" {
  description = "Monitoring EC2 instance ID"
  value       = aws_instance.monitoring.id
}

# ------------------------------------------------------------------------------
# SIP SERVER OUTPUTS
# ------------------------------------------------------------------------------

output "sip_public_ips" {
  description = "Public IP addresses for SIP server instances (SIP signaling traffic)"
  value       = aws_eip.sip[*].public_ip
}

output "sip_private_ips" {
  description = "Private IP addresses for SIP server instances"
  value       = aws_instance.sip[*].private_ip
}

output "sip_instance_ids" {
  description = "SIP EC2 instance IDs"
  value       = aws_instance.sip[*].id
}

# ------------------------------------------------------------------------------
# RTP SERVER OUTPUTS
# ------------------------------------------------------------------------------

output "rtp_public_ips" {
  description = "Public IP addresses for RTP server instances (RTP media traffic)"
  value       = aws_eip.rtp[*].public_ip
}

output "rtp_private_ips" {
  description = "Private IP addresses for RTP server instances"
  value       = aws_instance.rtp[*].private_ip
}

output "rtp_instance_ids" {
  description = "RTP EC2 instance IDs"
  value       = aws_instance.rtp[*].id
}

# ------------------------------------------------------------------------------
# FEATURE SERVER OUTPUTS
# ------------------------------------------------------------------------------

output "feature_server_asg_name" {
  description = "Feature Server Auto Scaling Group name"
  value       = aws_autoscaling_group.feature_server.name
}

# ------------------------------------------------------------------------------
# RECORDING SERVER OUTPUTS
# ------------------------------------------------------------------------------

output "recording_asg_name" {
  description = "Recording Server Auto Scaling Group name (if deployed)"
  value       = var.deploy_recording_cluster ? aws_autoscaling_group.recording[0].name : "Not deployed"
}

output "recording_alb_dns" {
  description = "Recording ALB DNS name (if deployed)"
  value       = var.deploy_recording_cluster ? aws_lb.recording[0].dns_name : "Not deployed"
}

# ------------------------------------------------------------------------------
# DATABASE OUTPUTS
# ------------------------------------------------------------------------------

output "aurora_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = aws_rds_cluster.jambonz.endpoint
  sensitive   = true
}

output "aurora_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.jambonz.reader_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = aws_elasticache_replication_group.jambonz.primary_endpoint_address
  sensitive   = true
}

# ------------------------------------------------------------------------------
# CREDENTIALS
# ------------------------------------------------------------------------------

output "portal_username" {
  description = "Login username for the jambonz portal"
  value       = "admin"
}

output "portal_password" {
  description = "Initial password for jambonz portal (the web instance ID - you will be forced to change it on first login)"
  value       = aws_instance.web.id
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

# ------------------------------------------------------------------------------
# SSH CONNECTION COMMANDS
# ------------------------------------------------------------------------------

output "ssh_connection_web" {
  description = "SSH connection command for Web server"
  value       = "ssh ${var.ssh_user}@${aws_eip.web.public_ip}"
}

output "ssh_connection_monitoring" {
  description = "SSH connection command for Monitoring server"
  value       = "ssh ${var.ssh_user}@${aws_eip.monitoring.public_ip}"
}

output "ssh_connection_sip" {
  description = "SSH connection commands for SIP servers"
  value       = [for ip in aws_eip.sip[*].public_ip : "ssh ${var.ssh_user}@${ip}"]
}

output "ssh_connection_rtp" {
  description = "SSH connection commands for RTP servers"
  value       = [for ip in aws_eip.rtp[*].public_ip : "ssh ${var.ssh_user}@${ip}"]
}

# ------------------------------------------------------------------------------
# DNS RECORDS
# ------------------------------------------------------------------------------

output "dns_records_required" {
  description = "DNS A records that need to be created"
  value = {
    "${var.url_portal}"             = aws_eip.web.public_ip
    "api.${var.url_portal}"         = aws_eip.web.public_ip
    "public-apps.${var.url_portal}" = aws_eip.web.public_ip
    "grafana.${var.url_portal}"     = aws_eip.monitoring.public_ip
    "homer.${var.url_portal}"       = aws_eip.monitoring.public_ip
    "sip.${var.url_portal}"         = aws_eip.sip[0].public_ip
  }
}

# ------------------------------------------------------------------------------
# NETWORKING
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.jambonz.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}
