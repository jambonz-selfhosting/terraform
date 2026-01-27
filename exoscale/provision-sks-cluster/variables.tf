# =============================================================================
# Exoscale API Credentials
# Can be set via terraform.tfvars or environment variables
# (EXOSCALE_API_KEY, EXOSCALE_API_SECRET)
# =============================================================================

variable "exoscale_api_key" {
  description = "Exoscale API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "exoscale_api_secret" {
  description = "Exoscale API secret"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Basic Configuration
# =============================================================================

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "jambonz"

  validation {
    condition     = length(var.name_prefix) > 0 && length(var.name_prefix) <= 20
    error_message = "name_prefix must be between 1 and 20 characters"
  }
}

variable "zone" {
  description = "Exoscale zone for deployment"
  type        = string
  default     = "ch-gva-2"

  validation {
    condition = contains([
      "ch-gva-2", "ch-dk-2", "de-fra-1", "de-muc-1",
      "at-vie-1", "at-vie-2", "bg-sof-1"
    ], var.zone)
    error_message = "zone must be a valid Exoscale zone"
  }
}

variable "cluster_name" {
  description = "Name of the SKS cluster"
  type        = string
  default     = "voip-sks-cluster"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must start with a letter, contain only lowercase letters, numbers, and hyphens, and end with a letter or number"
  }
}

# =============================================================================
# Cluster Configuration
# =============================================================================

variable "service_level" {
  description = "SKS service level: starter (free) or pro (HA control plane, Karpenter support)"
  type        = string
  default     = "pro"

  validation {
    condition     = contains(["starter", "pro"], var.service_level)
    error_message = "service_level must be 'starter' or 'pro'"
  }
}

variable "cni" {
  description = "CNI plugin: calico (default), cilium, or empty string for none"
  type        = string
  default     = "calico"

  validation {
    condition     = contains(["calico", "cilium", ""], var.cni)
    error_message = "cni must be 'calico', 'cilium', or empty string"
  }
}

variable "auto_upgrade" {
  description = "Enable automatic Kubernetes version upgrades"
  type        = bool
  default     = true
}

# =============================================================================
# System Node Pool Configuration
# =============================================================================

variable "system_instance_type" {
  description = "Instance type for system node pool"
  type        = string
  default     = "standard.medium"

  validation {
    condition = contains([
      "standard.micro", "standard.tiny", "standard.small", "standard.medium",
      "standard.large", "standard.extra-large", "standard.huge", "standard.mega",
      "standard.titan", "cpu.extra-large", "cpu.huge", "cpu.mega"
    ], var.system_instance_type)
    error_message = "system_instance_type must be a valid Exoscale instance type"
  }
}

variable "system_node_count" {
  description = "Number of nodes in system pool"
  type        = number
  default     = 2

  validation {
    condition     = var.system_node_count >= 1 && var.system_node_count <= 10
    error_message = "system_node_count must be between 1 and 10"
  }
}

variable "system_disk_size" {
  description = "Disk size in GB for system nodes"
  type        = number
  default     = 50

  validation {
    condition     = var.system_disk_size >= 20 && var.system_disk_size <= 1024
    error_message = "system_disk_size must be between 20 and 1024 GB"
  }
}

# =============================================================================
# SIP Node Pool Configuration
# =============================================================================

variable "sip_instance_type" {
  description = "Instance type for SIP node pool"
  type        = string
  default     = "standard.medium"

  validation {
    condition = contains([
      "standard.micro", "standard.tiny", "standard.small", "standard.medium",
      "standard.large", "standard.extra-large", "standard.huge", "standard.mega",
      "standard.titan", "cpu.extra-large", "cpu.huge", "cpu.mega"
    ], var.sip_instance_type)
    error_message = "sip_instance_type must be a valid Exoscale instance type"
  }
}

variable "sip_node_count" {
  description = "Number of nodes in SIP pool"
  type        = number
  default     = 1

  validation {
    condition     = var.sip_node_count >= 1 && var.sip_node_count <= 10
    error_message = "sip_node_count must be between 1 and 10"
  }
}

variable "sip_disk_size" {
  description = "Disk size in GB for SIP nodes"
  type        = number
  default     = 50

  validation {
    condition     = var.sip_disk_size >= 20 && var.sip_disk_size <= 1024
    error_message = "sip_disk_size must be between 20 and 1024 GB"
  }
}

# =============================================================================
# RTP Node Pool Configuration
# =============================================================================

variable "rtp_instance_type" {
  description = "Instance type for RTP node pool"
  type        = string
  default     = "standard.medium"

  validation {
    condition = contains([
      "standard.micro", "standard.tiny", "standard.small", "standard.medium",
      "standard.large", "standard.extra-large", "standard.huge", "standard.mega",
      "standard.titan", "cpu.extra-large", "cpu.huge", "cpu.mega"
    ], var.rtp_instance_type)
    error_message = "rtp_instance_type must be a valid Exoscale instance type"
  }
}

variable "rtp_node_count" {
  description = "Number of nodes in RTP pool"
  type        = number
  default     = 1

  validation {
    condition     = var.rtp_node_count >= 1 && var.rtp_node_count <= 10
    error_message = "rtp_node_count must be between 1 and 10"
  }
}

variable "rtp_disk_size" {
  description = "Disk size in GB for RTP nodes"
  type        = number
  default     = 50

  validation {
    condition     = var.rtp_disk_size >= 20 && var.rtp_disk_size <= 1024
    error_message = "rtp_disk_size must be between 20 and 1024 GB"
  }
}

# =============================================================================
# Security Configuration
# =============================================================================

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access to nodes"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr must be a valid CIDR block"
  }
}

variable "allowed_http_cidr" {
  description = "CIDR block allowed for HTTP/HTTPS access to system nodes"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_http_cidr, 0))
    error_message = "allowed_http_cidr must be a valid CIDR block"
  }
}

# =============================================================================
# Kubeconfig Configuration
# =============================================================================

variable "kubeconfig_ttl_seconds" {
  description = "TTL in seconds for the generated kubeconfig (default: 30 days)"
  type        = number
  default     = 2592000

  validation {
    condition     = var.kubeconfig_ttl_seconds >= 3600 && var.kubeconfig_ttl_seconds <= 31536000
    error_message = "kubeconfig_ttl_seconds must be between 3600 (1 hour) and 31536000 (1 year)"
  }
}
