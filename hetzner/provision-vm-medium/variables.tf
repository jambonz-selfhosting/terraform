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

# Instance Count Variables
variable "sbc_count" {
  description = "Number of SBC instances to create"
  type        = number
  default     = 1

  validation {
    condition     = var.sbc_count >= 1 && var.sbc_count <= 10
    error_message = "sbc_count must be between 1 and 10"
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

# Server Type Variables
variable "server_type_web" {
  description = "Hetzner server type for web/monitoring server"
  type        = string
  default     = "cx33"
}

variable "server_type_db" {
  description = "Hetzner server type for database server"
  type        = string
  default     = "cx33"
}

variable "server_type_sbc" {
  description = "Hetzner server type for SBC servers"
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

# Volume Size Variables (additional storage beyond server's built-in disk)
variable "volume_size_web" {
  description = "Additional volume size in GB for web/monitoring server"
  type        = number
  default     = 120

  validation {
    condition     = var.volume_size_web >= 10 && var.volume_size_web <= 10000
    error_message = "volume_size_web must be between 10 and 10000 GB"
  }
}


# Image Variables (jambonz snapshots uploaded to Hetzner)
variable "image_web_monitoring" {
  description = "Hetzner snapshot ID for web/monitoring server"
  type        = string
}

variable "image_sbc" {
  description = "Hetzner snapshot ID for SBC server"
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

variable "allowed_sbc_cidr" {
  description = "CIDR block allowed for SIP/RTP traffic to SBC"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_sbc_cidr, 0))
    error_message = "allowed_sbc_cidr must be a valid CIDR block"
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

# Database Credentials
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
  description = "Enable PCAP capture via Homer HEP endpoint on SBC servers"
  type        = string
  default     = "true"
}

variable "enable_otel" {
  description = "Enable OpenTelemetry tracing (Cassandra + Jaeger on monitoring server)"
  type        = string
  default     = "true"
}

variable "scale_in_timeout_seconds" {
  description = "Graceful scale-in timeout for feature servers (seconds)"
  type        = number
  default     = 900

  validation {
    condition     = var.scale_in_timeout_seconds >= 60 && var.scale_in_timeout_seconds <= 3600
    error_message = "scale_in_timeout_seconds must be between 60 and 3600 seconds"
  }
}

variable "krisp_license_key" {
  description = "Krisp license key for noise isolation and turn-taking (optional)"
  type        = string
  default     = ""
  sensitive   = true
}
