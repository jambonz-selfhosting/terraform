# =============================================================================
# Authentication
# Provide your Exoscale API credentials using ONE of these methods:
#
#   1. Variables: set in your .tfvars file or via -var
#      exoscale_api_key    = "your-api-key"
#      exoscale_api_secret = "your-api-secret"
#
#   2. Environment variables:
#      export EXOSCALE_API_KEY="your-api-key"
#      export EXOSCALE_API_SECRET="your-api-secret"
#
# Generate credentials in the Exoscale Console:
#   IAM → API Keys → Create API Key
# =============================================================================

variable "exoscale_api_key" {
  description = "Exoscale API key (leave empty to use EXOSCALE_API_KEY env var)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "exoscale_api_secret" {
  description = "Exoscale API secret (leave empty to use EXOSCALE_API_SECRET env var)"
  type        = string
  default     = ""
  sensitive   = true
}

# ------------------------------------------------------------------------------
# DEPLOYMENT CONFIGURATION
# ------------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string

  validation {
    condition     = length(var.name_prefix) > 0 && length(var.name_prefix) <= 20
    error_message = "name_prefix must be between 1 and 20 characters"
  }
}

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

variable "environment" {
  description = "Environment label (e.g., production, staging, dev)"
  type        = string
  default     = "production"
}

variable "url_portal" {
  description = "Domain name for the portal (e.g., jambonz.example.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.[a-z]{2,}$", var.url_portal))
    error_message = "url_portal must be a valid domain name"
  }
}

# ------------------------------------------------------------------------------
# INSTANCE CONFIGURATION
# ------------------------------------------------------------------------------

variable "jambonz_version" {
  description = "Jambonz version for template lookup (e.g., 10.0.4)"
  type        = string
  default     = "10.0.4"
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
  default     = 100

  validation {
    condition     = var.disk_size >= 10 && var.disk_size <= 400
    error_message = "Disk size must be between 10 and 400 GB."
  }
}

# ------------------------------------------------------------------------------
# SSH CONFIGURATION
# ------------------------------------------------------------------------------

variable "ssh_key_name" {
  description = "Existing SSH key name in Exoscale (if not providing ssh_public_key)"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key to use for instance access"
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# NETWORK ACCESS CONTROLS
# ------------------------------------------------------------------------------

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr must be a valid CIDR block"
  }
}

variable "allowed_sip_cidr" {
  description = "CIDR block allowed for SIP/RTP traffic"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_sip_cidr, 0))
    error_message = "allowed_sip_cidr must be a valid CIDR block"
  }
}

variable "allowed_http_cidr" {
  description = "CIDR block allowed for HTTP/HTTPS access"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_http_cidr, 0))
    error_message = "allowed_http_cidr must be a valid CIDR block"
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
# OPTIONAL FEATURES
# ------------------------------------------------------------------------------

variable "enable_pcaps" {
  description = "Enable PCAP capture via Homer HEP endpoint"
  type        = string
  default     = "true"
}

variable "enable_otel" {
  description = "Enable OpenTelemetry tracing (Cassandra + Jaeger)"
  type        = string
  default     = "true"
}

variable "apiban_key" {
  description = "APIBan API key for single-key mode (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "apiban_client_id" {
  description = "APIBan client ID for multi-key mode (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "apiban_client_secret" {
  description = "APIBan client secret for multi-key mode (optional)"
  type        = string
  default     = ""
  sensitive   = true
}
