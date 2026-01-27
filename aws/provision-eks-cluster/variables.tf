# =============================================================================
# Basic Configuration
# =============================================================================

variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "jambonz"

  validation {
    condition     = length(var.name_prefix) > 0 && length(var.name_prefix) <= 20
    error_message = "name_prefix must be between 1 and 20 characters"
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "voip-eks-cluster"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name))
    error_message = "cluster_name must start with a letter and contain only letters, numbers, and hyphens"
  }
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block"
  }
}

variable "availability_zone_count" {
  description = "Number of availability zones to use (minimum 2 for EKS)"
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be between 2 and 3"
  }
}

# =============================================================================
# System Node Group Configuration
# =============================================================================

variable "system_instance_type" {
  description = "EC2 instance type for system node group"
  type        = string
  default     = "t3.medium"
}

variable "system_node_count" {
  description = "Desired number of nodes in system node group"
  type        = number
  default     = 2

  validation {
    condition     = var.system_node_count >= 1 && var.system_node_count <= 10
    error_message = "system_node_count must be between 1 and 10"
  }
}

variable "system_min_count" {
  description = "Minimum number of nodes in system node group"
  type        = number
  default     = 1
}

variable "system_max_count" {
  description = "Maximum number of nodes in system node group"
  type        = number
  default     = 5
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
# SIP Node Group Configuration
# =============================================================================

variable "sip_instance_type" {
  description = "EC2 instance type for SIP node group"
  type        = string
  default     = "t3.medium"
}

variable "sip_node_count" {
  description = "Desired number of nodes in SIP node group"
  type        = number
  default     = 1

  validation {
    condition     = var.sip_node_count >= 1 && var.sip_node_count <= 10
    error_message = "sip_node_count must be between 1 and 10"
  }
}

variable "sip_min_count" {
  description = "Minimum number of nodes in SIP node group"
  type        = number
  default     = 1
}

variable "sip_max_count" {
  description = "Maximum number of nodes in SIP node group"
  type        = number
  default     = 10
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
# RTP Node Group Configuration
# =============================================================================

variable "rtp_instance_type" {
  description = "EC2 instance type for RTP node group"
  type        = string
  default     = "t3.medium"
}

variable "rtp_node_count" {
  description = "Desired number of nodes in RTP node group"
  type        = number
  default     = 1

  validation {
    condition     = var.rtp_node_count >= 1 && var.rtp_node_count <= 10
    error_message = "rtp_node_count must be between 1 and 10"
  }
}

variable "rtp_min_count" {
  description = "Minimum number of nodes in RTP node group"
  type        = number
  default     = 1
}

variable "rtp_max_count" {
  description = "Maximum number of nodes in RTP node group"
  type        = number
  default     = 10
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
# EKS Configuration
# =============================================================================

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster (leave empty for latest)"
  type        = string
  default     = ""
}

variable "cluster_log_types" {
  description = "EKS cluster log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}
