# Variables for jambonz medium cluster deployment on Azure

# ------------------------------------------------------------------------------
# AZURE CREDENTIALS
# ------------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# DEPLOYMENT CONFIGURATION
# ------------------------------------------------------------------------------

variable "location" {
  description = "Azure region to deploy in"
  type        = string
  default     = "eastus"
}

variable "name_prefix" {
  description = "Prefix for all resource names (must be lowercase, alphanumeric, max 10 chars for Key Vault compatibility)"
  type        = string
  default     = "jambonz"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,9}$", var.name_prefix))
    error_message = "Name prefix must be lowercase alphanumeric, start with a letter, and be 2-10 characters."
  }
}

variable "environment" {
  description = "Environment label (e.g., production, staging, dev)"
  type        = string
  default     = "production"
}

# ------------------------------------------------------------------------------
# NETWORK CONFIGURATION
# ------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR range for the VNet"
  type        = string
  default     = "172.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR for the first public subnet"
  type        = string
  default     = "172.20.10.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "public_subnet_cidr2" {
  description = "CIDR for the second public subnet (different availability zone)"
  type        = string
  default     = "172.20.11.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr2, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "mysql_subnet_cidr" {
  description = "CIDR for the MySQL delegated subnet"
  type        = string
  default     = "172.20.20.0/24"

  validation {
    condition     = can(cidrhost(var.mysql_subnet_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

# ------------------------------------------------------------------------------
# NETWORK ACCESS CONTROLS
# ------------------------------------------------------------------------------

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed SSH access (e.g., x.x.x.x/32 for single IP)"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "allowed_http_cidr" {
  description = "CIDR block allowed HTTP/HTTPS access"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_http_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "allowed_sbc_cidr" {
  description = "CIDR block allowed SIP/RTP access to SBC"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_sbc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "allowed_smpp_cidr" {
  description = "CIDR block allowed SMPP access"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_smpp_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

# ------------------------------------------------------------------------------
# IMAGE CONFIGURATION
# ------------------------------------------------------------------------------

variable "image_resource_group" {
  description = "Resource group containing the jambonz Packer images"
  type        = string
}

variable "sbc_image_name" {
  description = "Name of the SBC image in Azure"
  type        = string
  default     = ""
}

variable "sbc_image_id" {
  description = "Full resource ID of the SBC image (takes precedence over image_name)"
  type        = string
  default     = ""
}

variable "feature_server_image_name" {
  description = "Name of the Feature Server image in Azure"
  type        = string
  default     = ""
}

variable "feature_server_image_id" {
  description = "Full resource ID of the Feature Server image (takes precedence over image_name)"
  type        = string
  default     = ""
}

variable "web_monitoring_image_name" {
  description = "Name of the Web/Monitoring image in Azure"
  type        = string
  default     = ""
}

variable "web_monitoring_image_id" {
  description = "Full resource ID of the Web/Monitoring image (takes precedence over image_name)"
  type        = string
  default     = ""
}

variable "recording_image_name" {
  description = "Name of the Recording Server image in Azure"
  type        = string
  default     = ""
}

variable "recording_image_id" {
  description = "Full resource ID of the Recording Server image (takes precedence over image_name)"
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# VM SIZE CONFIGURATION
# ------------------------------------------------------------------------------

variable "sbc_vm_size" {
  description = "Azure VM size for SBC servers"
  type        = string
  default     = "Standard_F4s_v2"
}

variable "feature_server_vm_size" {
  description = "Azure VM size for Feature Servers"
  type        = string
  default     = "Standard_F4s_v2"
}

variable "web_monitoring_vm_size" {
  description = "Azure VM size for Web/Monitoring server"
  type        = string
  default     = "Standard_F4s_v2"
}

variable "recording_vm_size" {
  description = "Azure VM size for Recording Servers"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "web_monitoring_disk_size" {
  description = "Disk size in GB for the Web/Monitoring server"
  type        = number
  default     = 200

  validation {
    condition     = var.web_monitoring_disk_size >= 100 && var.web_monitoring_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "sbc_disk_size" {
  description = "Disk size in GB for SBC instances"
  type        = number
  default     = 100

  validation {
    condition     = var.sbc_disk_size >= 100 && var.sbc_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "feature_server_disk_size" {
  description = "Disk size in GB for Feature Server instances"
  type        = number
  default     = 100

  validation {
    condition     = var.feature_server_disk_size >= 100 && var.feature_server_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "recording_disk_size" {
  description = "Disk size in GB for Recording Server instances"
  type        = number
  default     = 100

  validation {
    condition     = var.recording_disk_size >= 100 && var.recording_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

# ------------------------------------------------------------------------------
# SBC CONFIGURATION
# ------------------------------------------------------------------------------

variable "sbc_count" {
  description = "Number of SBC instances to deploy (each gets a static public IP)"
  type        = number
  default     = 1

  validation {
    condition     = var.sbc_count >= 1 && var.sbc_count <= 10
    error_message = "SBC count must be between 1 and 10."
  }
}

# ------------------------------------------------------------------------------
# SCALE SET CONFIGURATION
# ------------------------------------------------------------------------------

variable "feature_server_desired_capacity" {
  description = "Desired number of Feature Server instances"
  type        = number
  default     = 1
}

variable "feature_server_min_capacity" {
  description = "Minimum number of Feature Server instances"
  type        = number
  default     = 1
}

variable "feature_server_max_capacity" {
  description = "Maximum number of Feature Server instances"
  type        = number
  default     = 4
}

variable "recording_desired_capacity" {
  description = "Desired number of Recording Server instances"
  type        = number
  default     = 1
}

variable "recording_min_capacity" {
  description = "Minimum number of Recording Server instances"
  type        = number
  default     = 1
}

variable "recording_max_capacity" {
  description = "Maximum number of Recording Server instances"
  type        = number
  default     = 8
}

# ------------------------------------------------------------------------------
# SSH CONFIGURATION
# ------------------------------------------------------------------------------

variable "ssh_public_key" {
  description = "SSH public key content for VM access"
  type        = string
}

# ------------------------------------------------------------------------------
# DATABASE CONFIGURATION
# ------------------------------------------------------------------------------

variable "mysql_username" {
  description = "MySQL admin username (cannot be admin, root, administrator, etc. due to Azure restrictions)"
  type        = string
  default     = "jambonz"
}

variable "mysql_password" {
  description = "MySQL admin password (leave empty to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "mysql_sku_name" {
  description = "Azure MySQL Flexible Server SKU"
  type        = string
  default     = "B_Standard_B2s"

  validation {
    condition = contains([
      "B_Standard_B1s",
      "B_Standard_B1ms",
      "B_Standard_B2s",
      "B_Standard_B2ms",
      "GP_Standard_D2ds_v4",
      "GP_Standard_D4ds_v4",
      "GP_Standard_D8ds_v4",
      "GP_Standard_D16ds_v4",
      "GP_Standard_D32ds_v4",
      "GP_Standard_D48ds_v4",
      "GP_Standard_D64ds_v4",
      "MO_Standard_E2ds_v4",
      "MO_Standard_E4ds_v4",
      "MO_Standard_E8ds_v4",
      "MO_Standard_E16ds_v4",
      "MO_Standard_E32ds_v4",
      "MO_Standard_E48ds_v4",
      "MO_Standard_E64ds_v4",
    ], var.mysql_sku_name)
    error_message = "MySQL SKU must be a valid Azure MySQL Flexible Server SKU."
  }
}

# ------------------------------------------------------------------------------
# REDIS CONFIGURATION
# ------------------------------------------------------------------------------

variable "redis_sku_name" {
  description = "Azure Redis Cache SKU name"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku_name)
    error_message = "Redis SKU must be Basic, Standard, or Premium."
  }
}

variable "redis_family" {
  description = "Azure Redis Cache family"
  type        = string
  default     = "C"

  validation {
    condition     = contains(["C", "P"], var.redis_family)
    error_message = "Redis family must be C (Basic/Standard) or P (Premium)."
  }
}

variable "redis_capacity" {
  description = "Azure Redis Cache capacity (size)"
  type        = number
  default     = 1

  validation {
    condition     = var.redis_capacity >= 0 && var.redis_capacity <= 6
    error_message = "Redis capacity must be between 0 and 6."
  }
}

# ------------------------------------------------------------------------------
# JAMBONZ CONFIGURATION
# ------------------------------------------------------------------------------

variable "url_portal" {
  description = "DNS name for the jambonz portal (e.g., jambonz.example.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]*\\.[a-zA-Z]{2,}$", var.url_portal))
    error_message = "Must be a valid domain name."
  }
}

variable "enable_pcaps" {
  description = "Enable PCAP capture for SIP traffic"
  type        = bool
  default     = true
}

variable "deploy_recording_cluster" {
  description = "Deploy the recording server cluster"
  type        = bool
  default     = true
}

variable "db_caching_tts" {
  description = "Number of seconds to cache results from DB queries (0=no caching)"
  type        = number
  default     = 0
}
