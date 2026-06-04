# =============================================================================
# Authentication
# Provide your Hetzner Cloud API token using ONE of these methods:
#
#   1. Variable: set hcloud_token in your .tfvars file or via -var
#      hcloud_token = "your-api-token"
#
#   2. Environment variable: export HCLOUD_TOKEN="your-api-token"
#
# Generate a token in the Hetzner Cloud Console:
#   Project → Security → API Tokens → Generate API Token (Read & Write)
# =============================================================================

variable "hcloud_token" {
  description = "Hetzner Cloud API token (leave empty to use HCLOUD_TOKEN env var)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string

  validation {
    condition     = length(var.name_prefix) > 0 && length(var.name_prefix) <= 20
    error_message = "name_prefix must be between 1 and 20 characters"
  }
}

variable "location" {
  description = "Hetzner Cloud location for deployment"
  type        = string
  default     = "nbg1"

  validation {
    condition     = contains(["nbg1", "fsn1", "hel1", "ash", "hil", "sgp1"], var.location)
    error_message = "location must be a valid Hetzner Cloud location (nbg1, fsn1, hel1, ash, hil, sgp1)"
  }
}

variable "url_portal" {
  description = "Domain name for the portal (e.g., jambonz.example.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.[a-z]{2,}$", var.url_portal))
    error_message = "url_portal must be a valid domain name"
  }
}

# Image Variable (jambonz mini snapshot uploaded to Hetzner)
variable "image_mini" {
  description = "Hetzner snapshot ID for the jambonz mini (all-in-one) server"
  type        = string
}

# Server Type
variable "server_type" {
  description = "Hetzner server type for the mini server"
  type        = string
  default     = "cx33"
}

# Security CIDR Variables
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

# SSH Key Variables
variable "ssh_public_key" {
  description = "SSH public key to use for instance access"
  type        = string
  default     = ""
}

variable "ssh_key_name" {
  description = "Existing SSH key name in Hetzner (if not providing ssh_public_key)"
  type        = string
  default     = ""
}

# Optional Variables
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

variable "krisp_license_key" {
  description = "Krisp license key for noise isolation and turn-taking (optional)"
  type        = string
  default     = ""
  sensitive   = true
}
