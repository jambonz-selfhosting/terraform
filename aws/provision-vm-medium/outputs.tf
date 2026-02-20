# Outputs for jambonz medium cluster deployment on AWS

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

output "web_monitoring_public_ip" {
  description = "Public IP address of the Web/Monitoring server - create DNS A records pointing to this IP"
  value       = aws_eip.web_monitoring.public_ip
}

output "web_monitoring_private_ip" {
  description = "Private IP address of the Web/Monitoring server"
  value       = aws_instance.web_monitoring.private_ip
}

output "sbc_public_ips" {
  description = "Public IP addresses for SBC instances (SIP traffic)"
  value       = aws_eip.sbc[*].public_ip
}

output "web_monitoring_instance_id" {
  description = "Web/Monitoring EC2 instance ID"
  value       = aws_instance.web_monitoring.id
}

output "sbc_asg_name" {
  description = "SBC Auto Scaling Group name"
  value       = aws_autoscaling_group.sbc.name
}

output "feature_server_asg_name" {
  description = "Feature Server Auto Scaling Group name"
  value       = aws_autoscaling_group.feature_server.name
}

output "recording_asg_name" {
  description = "Recording Server Auto Scaling Group name (if deployed)"
  value       = var.deploy_recording_cluster ? aws_autoscaling_group.recording[0].name : "Not deployed"
}

output "recording_alb_dns" {
  description = "Recording ALB DNS name (if deployed)"
  value       = var.deploy_recording_cluster ? aws_lb.recording[0].dns_name : "Not deployed"
}

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

output "portal_username" {
  description = "Login username for the jambonz portal"
  value       = "admin"
}

output "portal_password" {
  description = "Initial password for jambonz portal (the web-monitoring instance ID - you will be forced to change it on first login)"
  value       = aws_instance.web_monitoring.id
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

output "ssh_connection_web_monitoring" {
  description = "SSH connection command for Web/Monitoring server"
  value       = "ssh ${var.ssh_user}@${aws_eip.web_monitoring.public_ip}"
}

output "dns_records_required" {
  description = "DNS A records that need to be created"
  value = {
    "${var.url_portal}"             = aws_eip.web_monitoring.public_ip
    "api.${var.url_portal}"         = aws_eip.web_monitoring.public_ip
    "grafana.${var.url_portal}"     = aws_eip.web_monitoring.public_ip
    "homer.${var.url_portal}"       = aws_eip.web_monitoring.public_ip
    "public-apps.${var.url_portal}" = aws_eip.web_monitoring.public_ip
    "sip.${var.url_portal}"         = aws_eip.sbc[0].public_ip
  }
}

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
