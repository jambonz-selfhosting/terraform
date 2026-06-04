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

variable "vpc_cidr" {
  description = "CIDR block for the private network"
  type        = string
  default     = "172.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block"
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

# =============================================================================
# Instance Count Variables
# =============================================================================

variable "sip_count" {
  description = "Number of SIP server instances to create"
  type        = number
  default     = 1

  validation {
    condition     = var.sip_count >= 1 && var.sip_count <= 10
    error_message = "sip_count must be between 1 and 10"
  }
}

variable "rtp_count" {
  description = "Number of RTP server instances to create"
  type        = number
  default     = 1

  validation {
    condition     = var.rtp_count >= 1 && var.rtp_count <= 10
    error_message = "rtp_count must be between 1 and 10"
  }
}

variable "feature_server_count" {
  description = "Number of feature server instances"
  type        = number
  default     = 1

  validation {
    condition     = var.feature_server_count >= 1 && var.feature_server_count <= 10
    error_message = "feature_server_count must be between 1 and 10"
  }
}

variable "recording_server_count" {
  description = "Number of recording server instances"
  type        = number
  default     = 1

  validation {
    condition     = var.recording_server_count >= 1 && var.recording_server_count <= 10
    error_message = "recording_server_count must be between 1 and 10"
  }
}

variable "deploy_recording_cluster" {
  description = "Whether to deploy the recording cluster"
  type        = bool
  default     = false
}

# =============================================================================
# Server Type Variables
# =============================================================================

variable "server_type_web" {
  description = "Hetzner server type for web server"
  type        = string
  default     = "cx33"
}

variable "server_type_monitoring" {
  description = "Hetzner server type for monitoring server"
  type        = string
  default     = "cx33"
}

variable "server_type_db" {
  description = "Hetzner server type for database server"
  type        = string
  default     = "cx33"
}

variable "server_type_sip" {
  description = "Hetzner server type for SIP servers"
  type        = string
  default     = "cx33"
}

variable "server_type_rtp" {
  description = "Hetzner server type for RTP servers"
  type        = string
  default     = "cx33"
}

variable "server_type_feature" {
  description = "Hetzner server type for feature servers"
  type        = string
  default     = "cx33"
}

variable "server_type_recording" {
  description = "Hetzner server type for recording servers"
  type        = string
  default     = "cx33"
}

# =============================================================================
# Volume Size Variables
# =============================================================================

variable "volume_size_monitoring" {
  description = "Additional volume size in GB for monitoring server (InfluxDB, Cassandra)"
  type        = number
  default     = 120

  validation {
    condition     = var.volume_size_monitoring >= 10 && var.volume_size_monitoring <= 10000
    error_message = "volume_size_monitoring must be between 10 and 10000 GB"
  }
}

# =============================================================================
# Image Variables (jambonz snapshots uploaded to Hetzner)
# =============================================================================

variable "image_web" {
  description = "Hetzner snapshot ID for web server"
  type        = string
}

variable "image_monitoring" {
  description = "Hetzner snapshot ID for monitoring server"
  type        = string
}

variable "image_sip" {
  description = "Hetzner snapshot ID for SIP server"
  type        = string
}

variable "image_rtp" {
  description = "Hetzner snapshot ID for RTP server"
  type        = string
}

variable "image_feature_server" {
  description = "Hetzner snapshot ID for feature server"
  type        = string
}

variable "image_recording" {
  description = "Hetzner snapshot ID for recording server"
  type        = string
  default     = ""
}

variable "image_db" {
  description = "Hetzner snapshot ID for database server"
  type        = string
}

# =============================================================================
# Security CIDR Variables
# =============================================================================

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

# =============================================================================
# SSH Key Variables
# =============================================================================

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

# =============================================================================
# Database Credentials
# =============================================================================

variable "mysql_username" {
  description = "MySQL admin username"
  type        = string
  default     = "admin"
}

variable "mysql_password" {
  description = "MySQL admin password (leave empty for auto-generation)"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Optional Variables
# =============================================================================

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
  description = "Enable OpenTelemetry tracing (Cassandra + Jaeger on monitoring server)"
  type        = string
  default     = "true"
}

variable "krisp_license_key" {
  description = "Krisp license key for noise isolation and turn-taking (optional)"
  type        = string
  default     = ""
  sensitive   = true
}
