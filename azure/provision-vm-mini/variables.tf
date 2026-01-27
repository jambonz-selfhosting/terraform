# Variables for jambonz mini deployment on Azure

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

  validation {
    condition = contains([
      "eastus",
      "eastus2",
      "westus",
      "westus2",
      "westus3",
      "centralus",
      "northcentralus",
      "southcentralus",
      "westcentralus",
      "canadacentral",
      "canadaeast",
      "brazilsouth",
      "northeurope",
      "westeurope",
      "uksouth",
      "ukwest",
      "francecentral",
      "francesouth",
      "switzerlandnorth",
      "switzerlandwest",
      "germanywestcentral",
      "norwayeast",
      "swedencentral",
      "eastasia",
      "southeastasia",
      "japaneast",
      "japanwest",
      "australiaeast",
      "australiasoutheast",
      "australiacentral",
      "koreacentral",
      "koreasouth",
      "centralindia",
      "southindia",
      "westindia",
      "uaenorth",
      "uaecentral",
      "southafricanorth",
      "southafricawest",
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "jambonz"
}

variable "environment" {
  description = "Environment label (e.g., production, staging, dev)"
  type        = string
  default     = "production"
}

# ------------------------------------------------------------------------------
# IMAGE CONFIGURATION
# ------------------------------------------------------------------------------

variable "image_name" {
  description = "Name of the jambonz image in Azure. Used if image_id is not set."
  type        = string
  default     = ""
}

variable "image_resource_group" {
  description = "Resource group containing the jambonz image. Required if using image_name."
  type        = string
  default     = ""
}

variable "image_id" {
  description = "Full resource ID of the jambonz image in Azure. Takes precedence over image_name."
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# INSTANCE CONFIGURATION
# ------------------------------------------------------------------------------

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_D2s_v3"

  validation {
    condition = contains([
      "Standard_B2s",
      "Standard_B2ms",
      "Standard_B4ms",
      "Standard_D2s_v3",
      "Standard_D4s_v3",
      "Standard_D8s_v3",
      "Standard_D2s_v4",
      "Standard_D4s_v4",
      "Standard_D8s_v4",
      "Standard_D2s_v5",
      "Standard_D4s_v5",
      "Standard_D8s_v5",
      "Standard_E2s_v3",
      "Standard_E4s_v3",
      "Standard_E2s_v4",
      "Standard_E4s_v4",
      "Standard_E2s_v5",
      "Standard_E4s_v5",
      "Standard_F2s_v2",
      "Standard_F4s_v2",
      "Standard_F8s_v2",
    ], var.vm_size)
    error_message = "VM size must be a valid Azure VM size."
  }
}

variable "disk_size" {
  description = "OS disk size in GB"
  type        = number
  default     = 50

  validation {
    condition     = var.disk_size >= 30 && var.disk_size <= 1024
    error_message = "Disk size must be between 30 and 1024 GB."
  }
}

# ------------------------------------------------------------------------------
# SSH CONFIGURATION
# ------------------------------------------------------------------------------

variable "ssh_public_key" {
  description = "SSH public key content for VM access"
  type        = string
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

variable "allowed_sip_cidr" {
  description = "CIDR block allowed SIP access"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_sip_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "allowed_rtp_cidr" {
  description = "CIDR block allowed RTP access"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_rtp_cidr, 0))
    error_message = "Must be a valid CIDR block."
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

# ------------------------------------------------------------------------------
# OPTIONAL SERVICES
# ------------------------------------------------------------------------------

variable "apiban_key" {
  description = "APIBan API key for VoIP fraud/spam protection (optional). Get a free key at https://apiban.org"
  type        = string
  default     = ""
  sensitive   = true
}
