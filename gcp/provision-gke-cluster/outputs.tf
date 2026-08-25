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

output "rtp_static_ips" {
  description = "Static IP addresses for RTP nodes"
  value       = google_compute_address.rtp[*].address
}

output "voip_node_locations" {
  description = "Zones the SIP and RTP node pools run in (node_count is per zone)"
  value       = local.voip_zones
}

output "eip_allocator_helm_values" {
  description = "Helm values for eip-allocator init container (sbc.eipAllocator.*)"
  # These must be the labels actually on the addresses above. This output used to
  # report "${var.cluster_name}-sip-node", which matches nothing: the label is a
  # plain "sip-node". Anyone who set the helm value from this output got
  # "No free static IPs available in pool role=<cluster>-sip-node" and an SBC pod
  # that never started, while the addresses sat there unused.
  value = {
    sipEipGroupRoleKey = "role"
    sipEipGroupRole    = "sip-node"
    rtpEipGroupRoleKey = "role"
    rtpEipGroupRole    = "rtp-node"
  }
}
