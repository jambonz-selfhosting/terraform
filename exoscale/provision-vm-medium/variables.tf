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

# Custom Template Variables
# Note: Must be template IDs (UUID format), not names
# Use: exo compute template list --zone ch-gva-2 --visibility private
variable "template_web_monitoring" {
  description = "Custom Exoscale template ID for web/monitoring server (UUID format)"
  type        = string
}

variable "template_sbc" {
  description = "Custom Exoscale template ID for SBC servers (UUID format)"
  type        = string
}

variable "template_feature_server" {
  description = "Custom Exoscale template ID for feature servers (UUID format)"
  type        = string
}

variable "template_recording" {
  description = "Custom Exoscale template ID for recording servers (UUID format)"
  type        = string
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
  default     = false
}

# Database Plan Variables
variable "mysql_plan" {
  description = "Exoscale DBaaS MySQL plan (hobbyist-2, startup-4/8/16/32, business-4/8/16/32, premium-*)"
  type        = string
  default     = "hobbyist-2"

  validation {
    condition     = can(regex("^(hobbyist-2|startup-(4|8|16|32|64|128|225)|business-(4|8|16|32|64|128|225)|premium-(4|8|16|32|64|128|225))$", var.mysql_plan))
    error_message = "mysql_plan must be a valid Exoscale DBaaS plan"
  }
}

variable "valkey_plan" {
  description = "Exoscale DBaaS Valkey plan (hobbyist-2, startup-4/8/16/32, business-4/8/16/32, premium-*)"
  type        = string
  default     = "hobbyist-2"

  validation {
    condition     = can(regex("^(hobbyist-2|startup-(4|8|16|32|64|128|225)|business-(1|4|8|16|32|64|128|225)|premium-(4|8|16|32|64|128|225))$", var.valkey_plan))
    error_message = "valkey_plan must be a valid Exoscale DBaaS Valkey plan"
  }
}

# Instance Type Variables
variable "instance_type_web" {
  description = "Instance type for web/monitoring server"
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

variable "instance_type_sbc" {
  description = "Instance type for SBC servers"
  type        = string
  default     = "standard.medium"

  validation {
    condition = contains([
      "standard.micro", "standard.tiny", "standard.small", "standard.medium",
      "standard.large", "standard.extra-large", "standard.huge", "standard.mega",
      "standard.titan", "cpu.extra-large", "cpu.huge", "cpu.mega"
    ], var.instance_type_sbc)
    error_message = "instance_type_sbc must be a valid Exoscale instance type"
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

# Disk Size Variables
variable "disk_size_web" {
  description = "Disk size in GB for web/monitoring server"
  type        = number
  default     = 200

  validation {
    condition     = var.disk_size_web >= 100 && var.disk_size_web <= 1024
    error_message = "disk_size_web must be between 100 and 1024 GB"
  }
}

variable "disk_size_sbc" {
  description = "Disk size in GB for each SBC server"
  type        = number
  default     = 100

  validation {
    condition     = var.disk_size_sbc >= 50 && var.disk_size_sbc <= 1024
    error_message = "disk_size_sbc must be between 50 and 1024 GB"
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
  description = "Existing SSH key name in Exoscale (if not providing ssh_public_key)"
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
  description = "APiBan API key for fraud/spam IP blocking (optional)"
  type        = string
  default     = ""
  sensitive   = true
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
