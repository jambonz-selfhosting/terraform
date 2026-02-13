# Variables for jambonz mini deployment on Oracle Cloud Infrastructure (OCI)

# ------------------------------------------------------------------------------
# OCI CREDENTIALS
# ------------------------------------------------------------------------------

variable "tenancy_ocid" {
  description = "OCI tenancy OCID"
  type        = string
  sensitive   = true
}

variable "user_ocid" {
  description = "OCI user OCID"
  type        = string
  sensitive   = true
}

variable "fingerprint" {
  description = "Fingerprint of the OCI API signing key"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "Path to the OCI API private key file"
  type        = string
}

variable "compartment_id" {
  description = "OCI compartment OCID where resources will be created"
  type        = string
}

variable "region" {
  description = "OCI region (e.g., us-ashburn-1, eu-frankfurt-1)"
  type        = string
  default     = "us-ashburn-1"
}

# ------------------------------------------------------------------------------
# DEPLOYMENT CONFIGURATION
# ------------------------------------------------------------------------------

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

variable "availability_domain_number" {
  description = "Availability domain number (1, 2, or 3). If not specified, the first AD is used."
  type        = number
  default     = 1

  validation {
    condition     = var.availability_domain_number >= 1 && var.availability_domain_number <= 3
    error_message = "Availability domain number must be 1, 2, or 3."
  }
}

# ------------------------------------------------------------------------------
# JAMBONZ IMAGE CONFIGURATION
# Images are imported from a Pre-Authenticated Request (PAR) URL
# ------------------------------------------------------------------------------

variable "image_par_url" {
  description = "Pre-Authenticated Request URL for the jambonz mini image (from Object Storage)"
  type        = string
  default     = "https://id580apywcz8.objectstorage.us-ashburn-1.oci.customer-oci.com/p/-khjAVFGyYdtM66-d4DQ0-BoVSa8ECHe52nFZRmPvlql-jiDjWAzy2RMPx3nzZEL/n/id580apywcz8/b/jambonz-images/o/jambonz-mini-v10.0.4-dkms.oci"

  validation {
    condition     = can(regex("^https://.*", var.image_par_url))
    error_message = "Image PAR URL must be a valid HTTPS URL."
  }
}

# ------------------------------------------------------------------------------
# INSTANCE CONFIGURATION
# ------------------------------------------------------------------------------

variable "shape" {
  description = "OCI compute shape (flexible shapes recommended)"
  type        = string
  default     = "VM.Standard.E4.Flex"

  validation {
    condition = contains([
      "VM.Standard.E4.Flex",
      "VM.Standard.E5.Flex",
      "VM.Standard3.Flex",
      "VM.Optimized3.Flex",
    ], var.shape)
    error_message = "Shape must be a supported flexible shape."
  }
}

variable "ocpus" {
  description = "Number of OCPUs for flexible shapes"
  type        = number
  default     = 4

  validation {
    condition     = var.ocpus >= 1 && var.ocpus <= 64
    error_message = "OCPUs must be between 1 and 64."
  }
}

variable "memory_in_gbs" {
  description = "Memory in GB for flexible shapes"
  type        = number
  default     = 8

  validation {
    condition     = var.memory_in_gbs >= 1 && var.memory_in_gbs <= 1024
    error_message = "Memory must be between 1 and 1024 GB."
  }
}

variable "disk_size" {
  description = "Boot volume size in GB"
  type        = number
  default     = 200

  validation {
    condition     = var.disk_size >= 50 && var.disk_size <= 32768
    error_message = "Disk size must be between 50 and 32768 GB."
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
# NETWORK CONFIGURATION
# ------------------------------------------------------------------------------

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
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
