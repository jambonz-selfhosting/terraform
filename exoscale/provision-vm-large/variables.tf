variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string

  validation {
    condition     = length(var.name_prefix) > 0 && length(var.name_prefix) <= 20
    error_message = "name_prefix must be between 1 and 20 characters"
  }
}

variable "zone" {
  description = "Exoscale zone for deployment"
  type        = string
  default     = "ch-gva-2"

  validation {
    condition = contains([
      "ch-gva-2", "ch-dk-2", "de-fra-1", "de-muc-1",
      "at-vie-1", "at-vie-2", "bg-sof-1"
    ], var.zone)
    error_message = "zone must be a valid Exoscale zone"
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

variable "jambonz_version" {
  description = "Jambonz version for template lookup (e.g., 10.0.4)"
  type        = string
  default     = "10.0.4"
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
  description = "Number of feature server instances in the pool"
  type        = number
  default     = 1

  validation {
    condition     = var.feature_server_count >= 1 && var.feature_server_count <= 10
    error_message = "feature_server_count must be between 1 and 10"
  }
}

variable "recording_server_count" {
  description = "Number of recording server instances in the pool"
  type        = number
  default     = 1

  validation {
    condition     = var.recording_server_count >= 1 && var.recording_server_count <= 10
    error_message = "recording_server_count must be between 1 and 10"
  }
}

variable "deploy_recording_cluster" {
  description = "Whether to deploy the recording cluster (set to false to save costs)"
  type        = bool
  default     = true
}

# =============================================================================
# Instance Type Variables
# =============================================================================

variable "instance_type_db" {
  description = "Instance type for database server"
  type        = string
  default     = "standard.medium"

  validation {
    condition = contains([
      "standard.micro", "standard.tiny", "standard.small", "standard.medium",
      "standard.large", "standard.extra-large", "standard.huge", "standard.mega",
      "standard.titan", "cpu.extra-large", "cpu.huge", "cpu.mega"
    ], var.instance_type_db)
    error_message = "instance_type_db must be a valid Exoscale instance type"
  }
}


variable "instance_type_web" {
  description = "Instance type for web server"
  type        = string
  default     = "standard.medium"

  validation {
    condition = contains([
      "standard.micro", "standard.tiny", "standard.small", "standard.medium",
      "standard.large", "standard.extra-large", "standard.huge", "standard.mega",
      "standard.titan", "cpu.extra-large", "cpu.huge", "cpu.mega"
    ], var.instance_type_web)
    error_message = "instance_type_web must be a valid Exoscale instance type"
  }
}

variable "instance_type_monitoring" {
  description = "Instance type for monitoring server"
  type        = string
  default     = "standard.medium"

  validation {
    condition = contains([
      "standard.micro", "standard.tiny", "standard.small", "standard.medium",
      "standard.large", "standard.extra-large", "standard.huge", "standard.mega",
      "standard.titan", "cpu.extra-large", "cpu.huge", "cpu.mega"
    ], var.instance_type_monitoring)
    error_message = "instance_type_monitoring must be a valid Exoscale instance type"
  }
}

variable "instance_type_sip" {
  description = "Instance type for SIP servers"
  type        = string
  default     = "standard.medium"

  validation {
    condition = contains([
      "standard.micro", "standard.tiny", "standard.small", "standard.medium",
      "standard.large", "standard.extra-large", "standard.huge", "standard.mega",
      "standard.titan", "cpu.extra-large", "cpu.huge", "cpu.mega"
    ], var.instance_type_sip)
    error_message = "instance_type_sip must be a valid Exoscale instance type"
  }
}

variable "instance_type_rtp" {
  description = "Instance type for RTP servers"
  type        = string
  default     = "standard.medium"

  validation {
    condition = contains([
      "standard.micro", "standard.tiny", "standard.small", "standard.medium",
      "standard.large", "standard.extra-large", "standard.huge", "standard.mega",
      "standard.titan", "cpu.extra-large", "cpu.huge", "cpu.mega"
    ], var.instance_type_rtp)
    error_message = "instance_type_rtp must be a valid Exoscale instance type"
  }
}

variable "instance_type_feature" {
  description = "Instance type for feature servers"
  type        = string
  default     = "standard.medium"

  validation {
    condition = contains([
      "standard.micro", "standard.tiny", "standard.small", "standard.medium",
      "standard.large", "standard.extra-large", "standard.huge", "standard.mega",
      "standard.titan", "cpu.extra-large", "cpu.huge", "cpu.mega"
    ], var.instance_type_feature)
    error_message = "instance_type_feature must be a valid Exoscale instance type"
  }
}

variable "instance_type_recording" {
  description = "Instance type for recording servers"
  type        = string
  default     = "standard.medium"

  validation {
    condition = contains([
      "standard.micro", "standard.tiny", "standard.small", "standard.medium",
      "standard.large", "standard.extra-large", "standard.huge", "standard.mega",
      "standard.titan", "cpu.extra-large", "cpu.huge", "cpu.mega"
    ], var.instance_type_recording)
    error_message = "instance_type_recording must be a valid Exoscale instance type"
  }
}

# =============================================================================
# Disk Size Variables
# =============================================================================

variable "disk_size_db" {
  description = "Disk size in GB for database server"
  type        = number
  default     = 100

  validation {
    condition     = var.disk_size_db >= 50 && var.disk_size_db <= 1024
    error_message = "disk_size_db must be between 50 and 1024 GB"
  }
}

variable "disk_size_web" {
  description = "Disk size in GB for web server"
  type        = number
  default     = 100

  validation {
    condition     = var.disk_size_web >= 50 && var.disk_size_web <= 1024
    error_message = "disk_size_web must be between 50 and 1024 GB"
  }
}

variable "disk_size_monitoring" {
  description = "Disk size in GB for monitoring server"
  type        = number
  default     = 200

  validation {
    condition     = var.disk_size_monitoring >= 100 && var.disk_size_monitoring <= 1024
    error_message = "disk_size_monitoring must be between 100 and 1024 GB"
  }
}

variable "disk_size_sip" {
  description = "Disk size in GB for each SIP server"
  type        = number
  default     = 100

  validation {
    condition     = var.disk_size_sip >= 50 && var.disk_size_sip <= 1024
    error_message = "disk_size_sip must be between 50 and 1024 GB"
  }
}

variable "disk_size_rtp" {
  description = "Disk size in GB for each RTP server"
  type        = number
  default     = 100

  validation {
    condition     = var.disk_size_rtp >= 50 && var.disk_size_rtp <= 1024
    error_message = "disk_size_rtp must be between 50 and 1024 GB"
  }
}

variable "disk_size_feature" {
  description = "Disk size in GB for each feature server"
  type        = number
  default     = 100

  validation {
    condition     = var.disk_size_feature >= 50 && var.disk_size_feature <= 1024
    error_message = "disk_size_feature must be between 50 and 1024 GB"
  }
}

variable "disk_size_recording" {
  description = "Disk size in GB for each recording server"
  type        = number
  default     = 100

  validation {
    condition     = var.disk_size_recording >= 50 && var.disk_size_recording <= 1024
    error_message = "disk_size_recording must be between 50 and 1024 GB"
  }
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
  description = "CIDR block allowed for SIP traffic to SIP servers"
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
  description = "Existing SSH key name in Exoscale (if not providing ssh_public_key)"
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

variable "enable_pcaps" {
  description = "Enable PCAP capture on SIP servers (sends HEP to Homer on monitoring server)"
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
