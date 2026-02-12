# Variables for jambonz medium cluster deployment on Oracle Cloud Infrastructure (OCI)

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
# NETWORK CONFIGURATION
# ------------------------------------------------------------------------------

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "172.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "172.20.10.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (database/redis)"
  type        = string
  default     = "172.20.20.0/24"

  validation {
    condition     = can(cidrhost(var.private_subnet_cidr, 0))
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
  description = "CIDR block allowed SIP access to SBC"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_sip_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "allowed_rtp_cidr" {
  description = "CIDR block allowed RTP access to SBC"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_rtp_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

# ------------------------------------------------------------------------------
# JAMBONZ IMAGE CONFIGURATION
# Images are imported from Pre-Authenticated Request (PAR) URLs
# Default PAR URLs point to official jambonz images
# ------------------------------------------------------------------------------

variable "sbc_image_par_url" {
  description = "PAR URL for the SBC image (drachtio + rtpengine)"
  type        = string
  # TODO: Add official PAR URL once SBC image is exported
  # default     = "https://objectstorage..."

  validation {
    condition     = can(regex("^https://.*", var.sbc_image_par_url))
    error_message = "Image PAR URL must be a valid HTTPS URL."
  }
}

variable "feature_server_image_par_url" {
  description = "PAR URL for the Feature Server image (FreeSWITCH)"
  type        = string
  # TODO: Add official PAR URL once Feature Server image is exported
  # default     = "https://objectstorage..."

  validation {
    condition     = can(regex("^https://.*", var.feature_server_image_par_url))
    error_message = "Image PAR URL must be a valid HTTPS URL."
  }
}

variable "web_monitoring_image_par_url" {
  description = "PAR URL for the Web/Monitoring image (portal, API, Grafana, Homer, Jaeger)"
  type        = string
  # TODO: Add official PAR URL once Web/Monitoring image is exported
  # default     = "https://objectstorage..."

  validation {
    condition     = can(regex("^https://.*", var.web_monitoring_image_par_url))
    error_message = "Image PAR URL must be a valid HTTPS URL."
  }
}

variable "recording_image_par_url" {
  description = "PAR URL for the Recording Server image (optional, only if deploy_recording_cluster is true)"
  type        = string
  # TODO: Add official PAR URL once Recording image is exported
  # default     = "https://objectstorage..."
  default     = ""
}

# ------------------------------------------------------------------------------
# VM SHAPE CONFIGURATION
# ------------------------------------------------------------------------------

# SBC Configuration
variable "sbc_shape" {
  description = "OCI compute shape for SBC instances (flexible shapes recommended)"
  type        = string
  default     = "VM.Standard.E4.Flex"

  validation {
    condition = contains([
      "VM.Standard.E4.Flex",
      "VM.Standard.E5.Flex",
      "VM.Standard3.Flex",
      "VM.Optimized3.Flex",
    ], var.sbc_shape)
    error_message = "Shape must be a supported flexible shape."
  }
}

variable "sbc_ocpus" {
  description = "Number of OCPUs for SBC instances"
  type        = number
  default     = 4
}

variable "sbc_memory_in_gbs" {
  description = "Memory in GB for SBC instances"
  type        = number
  default     = 8
}

variable "sbc_disk_size" {
  description = "Boot volume size in GB for SBC instances"
  type        = number
  default     = 200
}

variable "sbc_count" {
  description = "Number of SBC instances to deploy (each gets a static public IP)"
  type        = number
  default     = 1

  validation {
    condition     = var.sbc_count >= 1 && var.sbc_count <= 10
    error_message = "SBC count must be between 1 and 10."
  }
}

# Feature Server Configuration
variable "feature_server_shape" {
  description = "OCI compute shape for Feature Server instances"
  type        = string
  default     = "VM.Standard.E4.Flex"

  validation {
    condition = contains([
      "VM.Standard.E4.Flex",
      "VM.Standard.E5.Flex",
      "VM.Standard3.Flex",
      "VM.Optimized3.Flex",
    ], var.feature_server_shape)
    error_message = "Shape must be a supported flexible shape."
  }
}

variable "feature_server_ocpus" {
  description = "Number of OCPUs for Feature Server instances"
  type        = number
  default     = 4
}

variable "feature_server_memory_in_gbs" {
  description = "Memory in GB for Feature Server instances"
  type        = number
  default     = 8
}

variable "feature_server_disk_size" {
  description = "Boot volume size in GB for Feature Server instances"
  type        = number
  default     = 200
}

variable "feature_server_count" {
  description = "Number of Feature Server instances"
  type        = number
  default     = 1

  validation {
    condition     = var.feature_server_count >= 1 && var.feature_server_count <= 10
    error_message = "Feature Server count must be between 1 and 10."
  }
}

# Web/Monitoring Configuration
variable "web_monitoring_shape" {
  description = "OCI compute shape for Web/Monitoring instance"
  type        = string
  default     = "VM.Standard.E4.Flex"

  validation {
    condition = contains([
      "VM.Standard.E4.Flex",
      "VM.Standard.E5.Flex",
      "VM.Standard3.Flex",
      "VM.Optimized3.Flex",
    ], var.web_monitoring_shape)
    error_message = "Shape must be a supported flexible shape."
  }
}

variable "web_monitoring_ocpus" {
  description = "Number of OCPUs for Web/Monitoring instance"
  type        = number
  default     = 4
}

variable "web_monitoring_memory_in_gbs" {
  description = "Memory in GB for Web/Monitoring instance"
  type        = number
  default     = 8
}

variable "web_monitoring_disk_size" {
  description = "Boot volume size in GB for Web/Monitoring instance"
  type        = number
  default     = 200
}

# Recording Configuration
variable "recording_shape" {
  description = "OCI compute shape for Recording Server instances"
  type        = string
  default     = "VM.Standard.E4.Flex"

  validation {
    condition = contains([
      "VM.Standard.E4.Flex",
      "VM.Standard.E5.Flex",
      "VM.Standard3.Flex",
      "VM.Optimized3.Flex",
    ], var.recording_shape)
    error_message = "Shape must be a supported flexible shape."
  }
}

variable "recording_ocpus" {
  description = "Number of OCPUs for Recording Server instances"
  type        = number
  default     = 4
}

variable "recording_memory_in_gbs" {
  description = "Memory in GB for Recording Server instances"
  type        = number
  default     = 8
}

variable "recording_disk_size" {
  description = "Boot volume size in GB for Recording Server instances"
  type        = number
  default     = 200
}

variable "recording_count" {
  description = "Number of Recording Server instances"
  type        = number
  default     = 1

  validation {
    condition     = var.recording_count >= 0 && var.recording_count <= 10
    error_message = "Recording count must be between 0 and 10."
  }
}

variable "deploy_recording_cluster" {
  description = "Deploy the recording server cluster"
  type        = bool
  default     = true
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
# DATABASE CONFIGURATION (OCI MySQL HeatWave)
# ------------------------------------------------------------------------------

variable "mysql_shape" {
  description = "OCI MySQL HeatWave shape"
  type        = string
  default     = "MySQL.VM.Standard.E4.1.8GB"

  validation {
    condition = contains([
      "MySQL.VM.Standard.E3.1.8GB",
      "MySQL.VM.Standard.E3.1.16GB",
      "MySQL.VM.Standard.E3.2.32GB",
      "MySQL.VM.Standard.E3.4.64GB",
      "MySQL.VM.Standard.E4.1.8GB",
      "MySQL.VM.Standard.E4.1.16GB",
      "MySQL.VM.Standard.E4.2.32GB",
      "MySQL.VM.Standard.E4.4.64GB",
    ], var.mysql_shape)
    error_message = "MySQL shape must be a valid OCI MySQL HeatWave shape."
  }
}

variable "mysql_storage_size" {
  description = "MySQL storage size in GB"
  type        = number
  default     = 50

  validation {
    condition     = var.mysql_storage_size >= 50 && var.mysql_storage_size <= 131072
    error_message = "MySQL storage size must be between 50 and 131072 GB."
  }
}

variable "mysql_username" {
  description = "MySQL admin username"
  type        = string
  default     = "jambonz"
}

variable "mysql_password" {
  description = "MySQL admin password (leave empty to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}

# ------------------------------------------------------------------------------
# REDIS CONFIGURATION (OCI Cache with Redis)
# ------------------------------------------------------------------------------

variable "redis_node_count" {
  description = "Number of Redis nodes (1-5)"
  type        = number
  default     = 1

  validation {
    condition     = var.redis_node_count >= 1 && var.redis_node_count <= 5
    error_message = "Redis node count must be between 1 and 5."
  }
}

variable "redis_memory_in_gbs" {
  description = "Memory per Redis node in GB"
  type        = number
  default     = 8

  validation {
    condition     = var.redis_memory_in_gbs >= 2 && var.redis_memory_in_gbs <= 500
    error_message = "Redis memory must be between 2 and 500 GB."
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
  description = "Enable PCAP capture for SIP traffic"
  type        = bool
  default     = true
}
