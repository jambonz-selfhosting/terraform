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
  description = "Azure region to deploy in. See README for supported regions."
  type        = string
  default     = "eastus"

  validation {
    condition = contains([
      # Americas
      "eastus",
      "eastus2",
      "westus2",
      "westus3",
      "centralus",
      "northcentralus",
      "southcentralus",
      "canadacentral",
      "brazilsouth",
      # Europe
      "northeurope",
      "westeurope",
      "uksouth",
      "francecentral",
      "germanywestcentral",
      "swedencentral",
      # Asia Pacific
      "australiaeast",
      "southeastasia",
      "japaneast",
      "koreacentral",
      "centralindia",
      # Africa
      "southafricanorth",
      # Middle East
      "uaenorth",
    ], var.location)
    error_message = "Location must be a supported Azure region. Supported regions: eastus, eastus2, westus2, westus3, centralus, northcentralus, southcentralus, canadacentral, brazilsouth, northeurope, westeurope, uksouth, francecentral, germanywestcentral, swedencentral, australiaeast, southeastasia, japaneast, koreacentral, centralindia, southafricanorth, uaenorth. Contact support@jambonz.org if you need a different region."
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
# JAMBONZ IMAGE CONFIGURATION
# Images are pulled from the jambonz Azure Community Gallery
# ------------------------------------------------------------------------------

variable "jambonz_version" {
  description = "jambonz version to deploy (image version in community gallery)"
  type        = string
  default     = "11.1.2"
}

variable "community_gallery_name" {
  description = "Name of the Azure Community Gallery containing jambonz images"
  type        = string
  default     = "jambonz-8962e4f5-da0f-41ee-b094-8680ad38d302"
}

# ------------------------------------------------------------------------------
# ARCHITECTURE
# ------------------------------------------------------------------------------

variable "architecture" {
  description = "CPU architecture to deploy: amd64 (x86_64) or arm64 (Ampere). Selects the community gallery image definition; arm64 uses the -arm64 definitions and requires an Ampere vm_size."
  type        = string
  default     = "amd64"

  validation {
    condition     = contains(["amd64", "arm64"], var.architecture)
    error_message = "architecture must be \"amd64\" or \"arm64\"."
  }

  # Azure rejects an arm64 image on an x86 size (and vice versa) only when the
  # VM is created, part-way through apply, once the network and NSG already
  # exist. This moves that failure to plan time. Ampere sizes carry a "p" after
  # the vCPU count: Standard_D4pls_v6, Standard_D2ps_v6.
  validation {
    condition     = can(regex("^Standard_[A-Z]+[0-9]+p", var.vm_size)) == (var.architecture == "arm64")
    error_message = "Architecture mismatch: architecture and vm_size must agree. arm64 needs an Ampere size (Standard_D2pls_v6, Standard_D4pls_v6, Standard_D2ps_v6, ...); amd64 needs an x86 size (Standard_D2s_v3, Standard_F4s_v2, ...). The arm64 example file sets both."
  }
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
      # Ampere (arm64) -- pair with architecture = "arm64"
      "Standard_D2pls_v6",
      "Standard_D4pls_v6",
      "Standard_D8pls_v6",
      "Standard_D2ps_v6",
      "Standard_D4ps_v6",
      "Standard_D8ps_v6",
      # x86_64
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
  description = "OS disk size in GB. Must be at least as large as the OS disk in the gallery image (100 GB)."
  type        = number
  default     = 100

  validation {
    # Azure refuses a VM whose OS disk is smaller than the image's with a 409
    # OperationNotAllowed at apply time. The jambonz images are built with a
    # 100 GB OS disk (packer's os_disk_size_gb), so catch it at plan instead.
    condition     = var.disk_size >= 100 && var.disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB (the gallery image's OS disk is 100 GB)."
  }
}

# ------------------------------------------------------------------------------
# SSH CONFIGURATION
# ------------------------------------------------------------------------------

variable "ssh_public_key" {
  description = "SSH public key content for VM access"
  type        = string

  validation {
    condition     = length(var.ssh_public_key) > 0 && can(regex("^ssh-(rsa|ed25519|ecdsa)", var.ssh_public_key))
    error_message = "SSH public key is required and must start with ssh-rsa, ssh-ed25519, or ssh-ecdsa."
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
  description = "APIBan API key for single-key mode (optional). Get a free key at https://apiban.org/getkey.html"
  type        = string
  default     = ""
  sensitive   = true
}

variable "apiban_client_id" {
  description = "APIBan client ID for multi-key mode (optional). Contact APIBan for client access."
  type        = string
  default     = ""
  sensitive   = true
}

variable "apiban_client_secret" {
  description = "APIBan client secret for multi-key mode (optional). Used with client_id to auto-provision keys per instance."
  type        = string
  default     = ""
  sensitive   = true
}

variable "krisp_license_key" {
  description = "Krisp license key for noise isolation and turn-taking (optional)"
  type        = string
  default     = ""
  sensitive   = true
}
