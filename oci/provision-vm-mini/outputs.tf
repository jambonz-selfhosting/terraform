# Outputs for jambonz mini deployment on OCI

output "instance_id" {
  description = "OCID of the jambonz instance"
  value       = oci_core_instance.jambonz_mini.id
}

output "instance_name" {
  description = "Display name of the jambonz instance"
  value       = oci_core_instance.jambonz_mini.display_name
}

output "public_ip" {
  description = "Public IP address of the jambonz instance"
  value       = oci_core_instance.jambonz_mini.public_ip
}

output "private_ip" {
  description = "Private IP address of the jambonz instance"
  value       = oci_core_instance.jambonz_mini.private_ip
}

output "portal_url" {
  description = "URL for the jambonz portal (requires DNS configuration)"
  value       = "https://${var.url_portal}"
}

output "grafana_url" {
  description = "URL for Grafana monitoring dashboard"
  value       = "https://grafana.${var.url_portal}"
}

output "homer_url" {
  description = "URL for Homer SIP capture"
  value       = "https://homer.${var.url_portal}"
}

output "jaeger_url" {
  description = "URL for Jaeger tracing"
  value       = "https://jaeger.${var.url_portal}"
}

output "ssh_connection" {
  description = "SSH command to connect to the instance"
  value       = "ssh jambonz@${oci_core_instance.jambonz_mini.public_ip}"
}

output "admin_user" {
  description = "Admin username for the jambonz portal"
  value       = "admin"
}

output "admin_password" {
  description = "Initial admin password (instance ID - change after first login)"
  value       = oci_core_instance.jambonz_mini.id
  sensitive   = true
}

output "dns_records_required" {
  description = "DNS A records required for the deployment"
  value = {
    "${var.url_portal}"          = oci_core_instance.jambonz_mini.public_ip
    "api.${var.url_portal}"      = oci_core_instance.jambonz_mini.public_ip
    "grafana.${var.url_portal}"  = oci_core_instance.jambonz_mini.public_ip
    "homer.${var.url_portal}"    = oci_core_instance.jambonz_mini.public_ip
    "jaeger.${var.url_portal}"   = oci_core_instance.jambonz_mini.public_ip
    "sip.${var.url_portal}"      = oci_core_instance.jambonz_mini.public_ip
  }
}

output "vcn_id" {
  description = "OCID of the VCN"
  value       = oci_core_vcn.jambonz.id
}

output "subnet_id" {
  description = "OCID of the public subnet"
  value       = oci_core_subnet.public.id
}

output "image_id" {
  description = "OCID of the imported jambonz image"
  value       = oci_core_image.jambonz_mini.id
}

output "compartment_id" {
  description = "Compartment OCID where resources are deployed"
  value       = var.compartment_id
}

output "region" {
  description = "OCI region where resources are deployed"
  value       = var.region
}
