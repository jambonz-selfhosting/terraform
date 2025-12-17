# Basic Configuration
variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "voip-k8s-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "voip-k8s-cluster"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "voip-k8s"
}

# Network Configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "system_subnet_prefix" {
  description = "Address prefix for the system node pool subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "sip_subnet_prefix" {
  description = "Address prefix for the SIP node pool subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "rtp_subnet_prefix" {
  description = "Address prefix for the RTP node pool subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services (must not overlap with VNet)"
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service (must be within service_cidr)"
  type        = string
  default     = "172.16.0.10"
}

# System Node Pool Configuration
variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 2
}

variable "system_vm_size" {
  description = "VM size for system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

# SIP Node Pool Configuration
variable "sip_vm_size" {
  description = "VM size for SIP node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "sip_node_count" {
  description = "Initial number of nodes in SIP node pool"
  type        = number
  default     = 1
}

variable "sip_min_count" {
  description = "Minimum number of nodes in SIP node pool (autoscaling)"
  type        = number
  default     = 1
}

variable "sip_max_count" {
  description = "Maximum number of nodes in SIP node pool (autoscaling)"
  type        = number
  default     = 10
}

# RTP Node Pool Configuration
variable "rtp_vm_size" {
  description = "VM size for RTP node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "rtp_node_count" {
  description = "Initial number of nodes in RTP node pool"
  type        = number
  default     = 1
}

variable "rtp_min_count" {
  description = "Minimum number of nodes in RTP node pool (autoscaling)"
  type        = number
  default     = 1
}

variable "rtp_max_count" {
  description = "Maximum number of nodes in RTP node pool (autoscaling)"
  type        = number
  default     = 10
}