output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.main.name
}

output "cluster_region" {
  description = "GKE cluster region"
  value       = google_container_cluster.main.location
}

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.main.name
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --region ${google_container_cluster.main.location} --project ${var.project_id}"
}

# =============================================================================
# Static IP Outputs
# =============================================================================

output "sip_static_ips" {
  description = "Static IP addresses for SIP nodes"
  value       = google_compute_address.sip[*].address
}

output "eip_allocator_helm_values" {
  description = "Helm values for eip-allocator init container (sbc.eipAllocator.*)"
  value = {
    sipEipGroupRoleKey = "role"
    sipEipGroupRole    = "${var.cluster_name}-sip-node"
  }
}
