# Variables for jambonz mini deployment on Exoscale

# ------------------------------------------------------------------------------
# EXOSCALE CREDENTIALS
# ------------------------------------------------------------------------------

variable "exoscale_api_key" {
  description = "Exoscale API key"
  type        = string
  sensitive   = true
}

variable "exoscale_api_secret" {
  description = "Exoscale API secret"
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# DEPLOYMENT CONFIGURATION
# ------------------------------------------------------------------------------

variable "zone" {
  description = "Exoscale zone to deploy in"
  type        = string
  default     = "ch-gva-2"

  validation {
    condition = contains([
      "ch-gva-2",
      "ch-dk-2",
      "de-fra-1",
      "de-muc-1",
      "at-vie-1",
      "at-vie-2",
      "bg-sof-1",
    ], var.zone)
    error_message = "Zone must be a valid Exoscale zone."
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
# INSTANCE CONFIGURATION
# ------------------------------------------------------------------------------

variable "template_name" {
  description = "Name of the jambonz template (custom image) in Exoscale. Used if template_id is not set."
  type        = string
  default     = ""
}

variable "template_id" {
  description = "ID of the jambonz template (custom image) in Exoscale. Takes precedence over template_name."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Exoscale instance type"
  type        = string
  default     = "standard.medium"

  validation {
    condition = contains([
      "standard.micro",
      "standard.tiny",
      "standard.small",
      "standard.medium",
      "standard.large",
      "standard.extra-large",
      "standard.huge",
      "standard.mega",
      "standard.titan",
      "cpu.extra-large",
      "cpu.huge",
      "cpu.mega",
    ], var.instance_type)
    error_message = "Instance type must be a valid Exoscale instance type."
  }
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 50

  validation {
    condition     = var.disk_size >= 10 && var.disk_size <= 400
    error_message = "Disk size must be between 10 and 400 GB."
  }
}

# ------------------------------------------------------------------------------
# SSH CONFIGURATION
# ------------------------------------------------------------------------------

variable "ssh_key_name" {
  description = "Name of an existing SSH key in Exoscale (use this OR ssh_public_key)"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key content to create a new key (use this OR ssh_key_name)"
  type        = string
  default     = ""
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
