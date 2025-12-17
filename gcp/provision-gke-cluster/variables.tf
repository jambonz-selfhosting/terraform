# Basic Configuration
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-east1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "voip-gke-cluster"
}

# Network Configuration
variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "voip-network"
}

variable "system_subnet_cidr" {
  description = "CIDR for the system node pool subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "sip_subnet_cidr" {
  description = "CIDR for the SIP node pool subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "rtp_subnet_cidr" {
  description = "CIDR for the RTP node pool subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR range for services"
  type        = string
  default     = "10.2.0.0/16"
}

# System Node Pool Configuration
variable "system_machine_type" {
  description = "Machine type for system node pool"
  type        = string
  default     = "e2-standard-2"
}

# SIP Node Pool Configuration
variable "sip_machine_type" {
  description = "Machine type for SIP node pool"
  type        = string
  default     = "e2-standard-2"
}

variable "sip_node_count" {
  description = "Number of nodes in SIP node pool"
  type        = number
  default     = 1
}

# RTP Node Pool Configuration
variable "rtp_machine_type" {
  description = "Machine type for RTP node pool"
  type        = string
  default     = "e2-standard-2"
}

variable "rtp_node_count" {
  description = "Number of nodes in RTP node pool"
  type        = number
  default     = 1
}
