# Outputs for jambonz mini (single VM) deployment on AWS

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

output "public_ip" {
  description = "Public IP address of the mini server - create DNS A records pointing to this IP"
  value       = aws_eip.mini.public_ip
}

output "private_ip" {
  description = "Private IP address of the mini server"
  value       = aws_instance.mini.private_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.mini.id
}

output "portal_username" {
  description = "Login username for the jambonz portal"
  value       = "admin"
}

output "portal_password" {
  description = "Initial password for jambonz portal (the instance ID - you will be forced to change it on first login)"
  value       = aws_instance.mini.id
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

output "ssh_connection" {
  description = "SSH connection command for the mini server"
  value       = "ssh ${var.ssh_user}@${aws_eip.mini.public_ip}"
}

output "dns_records_required" {
  description = "DNS A records that need to be created"
  value = {
    "${var.url_portal}"         = aws_eip.mini.public_ip
    "api.${var.url_portal}"     = aws_eip.mini.public_ip
    "grafana.${var.url_portal}" = aws_eip.mini.public_ip
    "homer.${var.url_portal}"   = aws_eip.mini.public_ip
    "sip.${var.url_portal}"     = aws_eip.mini.public_ip
  }
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.jambonz.id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = aws_subnet.public.id
}
