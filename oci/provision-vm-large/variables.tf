# Variables for jambonz large cluster deployment on Oracle Cloud Infrastructure (OCI)
# Large deployment splits SIP/RTP and Web/Monitoring into separate server roles

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
  description = "CIDR block for the private subnet (database)"
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
  description = "CIDR block allowed SIP access to SIP servers"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_sip_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "allowed_rtp_cidr" {
  description = "CIDR block allowed RTP access to RTP servers"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_rtp_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

# ------------------------------------------------------------------------------
# JAMBONZ IMAGE CONFIGURATION
# Large deployment uses separate SIP, RTP, Web, and Monitoring images
# ------------------------------------------------------------------------------

variable "sip_image_par_url" {
  description = "PAR URL for the SIP image (drachtio only)"
  type        = string
  default     = "https://id580apywcz8.objectstorage.us-ashburn-1.oci.customer-oci.com/p/svcJNZ0AelJQxGg5ej00_hqbH5hhZtvGSvnI1W4lLY4XWOr6gFMRf6HeYHNEgOLu/n/id580apywcz8/b/jambonz-images/o/jambonz-sip-v10.0.4.oci"

  validation {
    condition     = can(regex("^https://.*", var.sip_image_par_url))
    error_message = "Image PAR URL must be a valid HTTPS URL."
  }
}

variable "rtp_image_par_url" {
  description = "PAR URL for the RTP image (rtpengine only)"
  type        = string
  default     = "https://id580apywcz8.objectstorage.us-ashburn-1.oci.customer-oci.com/p/Lbi6PbgQbsLznxIOYjKEelVReVfzgIk4iX3Fu1bjEh-UPQLcyD4xPR2_p-yzK_Ck/n/id580apywcz8/b/jambonz-images/o/jambonz-rtp-v10.0.4.oci"

  validation {
    condition     = can(regex("^https://.*", var.rtp_image_par_url))
    error_message = "Image PAR URL must be a valid HTTPS URL."
  }
}

variable "feature_server_image_par_url" {
  description = "PAR URL for the Feature Server image (FreeSWITCH)"
  type        = string
  default     = "https://id580apywcz8.objectstorage.us-ashburn-1.oci.customer-oci.com/p/yhBcJMMJPW1lwhoLr4wgIbkcfCv5uOQycMpzaWwwiaIzfDJO-AJbbQUt3A7VQa_b/n/id580apywcz8/b/jambonz-images/o/jambonz-fs-v10.0.4.oci"

  validation {
    condition     = can(regex("^https://.*", var.feature_server_image_par_url))
    error_message = "Image PAR URL must be a valid HTTPS URL."
  }
}

variable "web_image_par_url" {
  description = "PAR URL for the Web image (portal, API, webapp)"
  type        = string
  default     = "https://id580apywcz8.objectstorage.us-ashburn-1.oci.customer-oci.com/p/gavUFcl6K9gtIS0u5i2qD3IwythX75PkdXcTd8eTXmuy41cYiZKTKb6Ana0l8gjx/n/id580apywcz8/b/jambonz-images/o/jambonz-web-v10.0.4.oci"

  validation {
    condition     = can(regex("^https://.*", var.web_image_par_url))
    error_message = "Image PAR URL must be a valid HTTPS URL."
  }
}

variable "monitoring_image_par_url" {
  description = "PAR URL for the Monitoring image (Grafana, Homer, Jaeger, InfluxDB)"
  type        = string
  default     = "https://id580apywcz8.objectstorage.us-ashburn-1.oci.customer-oci.com/p/0yTUv4t9a1vy8sVcHvVN7MMdIGF4db0wgnr-pgy7cHH8-GUp6vSzTfx6ffFpGJ8R/n/id580apywcz8/b/jambonz-images/o/jambonz-monitoring-v10.0.4.oci"

  validation {
    condition     = can(regex("^https://.*", var.monitoring_image_par_url))
    error_message = "Image PAR URL must be a valid HTTPS URL."
  }
}

variable "recording_image_par_url" {
  description = "PAR URL for the Recording Server image (optional, only if deploy_recording_cluster is true)"
  type        = string
  default     = "https://id580apywcz8.objectstorage.us-ashburn-1.oci.customer-oci.com/p/UK83YeE0eRKUSGV_U8bQcP6kliqD6ZfBcsUKYwFtNlqCFtbgKfKXDR_AMvGW-QCq/n/id580apywcz8/b/jambonz-images/o/jambonz-recording-v10.0.4.oci"
}

# ------------------------------------------------------------------------------
# VM SHAPE CONFIGURATION
# ------------------------------------------------------------------------------

# SIP Server Configuration
variable "sip_shape" {
  description = "OCI compute shape for SIP server instances"
  type        = string
  default     = "VM.Standard.E4.Flex"

  validation {
    condition = contains([
      "VM.Standard.E4.Flex",
      "VM.Standard.E5.Flex",
      "VM.Standard3.Flex",
      "VM.Optimized3.Flex",
    ], var.sip_shape)
    error_message = "Shape must be a supported flexible shape."
  }
}

variable "sip_ocpus" {
  description = "Number of OCPUs for SIP server instances"
  type        = number
  default     = 4
}

variable "sip_memory_in_gbs" {
  description = "Memory in GB for SIP server instances"
  type        = number
  default     = 8
}

variable "sip_disk_size" {
  description = "Boot volume size in GB for SIP server instances"
  type        = number
  default     = 100
}

variable "sip_count" {
  description = "Number of SIP server instances to deploy (each gets a static public IP)"
  type        = number
  default     = 2

  validation {
    condition     = var.sip_count >= 1 && var.sip_count <= 20
    error_message = "SIP server count must be between 1 and 20."
  }
}

# RTP Server Configuration
variable "rtp_shape" {
  description = "OCI compute shape for RTP server instances"
  type        = string
  default     = "VM.Standard.E4.Flex"

  validation {
    condition = contains([
      "VM.Standard.E4.Flex",
      "VM.Standard.E5.Flex",
      "VM.Standard3.Flex",
      "VM.Optimized3.Flex",
    ], var.rtp_shape)
    error_message = "Shape must be a supported flexible shape."
  }
}

variable "rtp_ocpus" {
  description = "Number of OCPUs for RTP server instances"
  type        = number
  default     = 4
}

variable "rtp_memory_in_gbs" {
  description = "Memory in GB for RTP server instances"
  type        = number
  default     = 8
}

variable "rtp_disk_size" {
  description = "Boot volume size in GB for RTP server instances"
  type        = number
  default     = 100
}

variable "rtp_count" {
  description = "Number of RTP server instances"
  type        = number
  default     = 2

  validation {
    condition     = var.rtp_count >= 1 && var.rtp_count <= 20
    error_message = "RTP server count must be between 1 and 20."
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
  default     = 8
}

variable "feature_server_memory_in_gbs" {
  description = "Memory in GB for Feature Server instances"
  type        = number
  default     = 16
}

variable "feature_server_disk_size" {
  description = "Boot volume size in GB for Feature Server instances"
  type        = number
  default     = 100
}

variable "feature_server_count" {
  description = "Number of Feature Server instances"
  type        = number
  default     = 4

  validation {
    condition     = var.feature_server_count >= 1 && var.feature_server_count <= 20
    error_message = "Feature Server count must be between 1 and 20."
  }
}

# Web Server Configuration
variable "web_shape" {
  description = "OCI compute shape for Web server instance"
  type        = string
  default     = "VM.Standard.E4.Flex"

  validation {
    condition = contains([
      "VM.Standard.E4.Flex",
      "VM.Standard.E5.Flex",
      "VM.Standard3.Flex",
      "VM.Optimized3.Flex",
    ], var.web_shape)
    error_message = "Shape must be a supported flexible shape."
  }
}

variable "web_ocpus" {
  description = "Number of OCPUs for Web server instance"
  type        = number
  default     = 4
}

variable "web_memory_in_gbs" {
  description = "Memory in GB for Web server instance"
  type        = number
  default     = 8
}

variable "web_disk_size" {
  description = "Boot volume size in GB for Web server instance"
  type        = number
  default     = 100
}

# Monitoring Server Configuration
variable "monitoring_shape" {
  description = "OCI compute shape for Monitoring server instance"
  type        = string
  default     = "VM.Standard.E4.Flex"

  validation {
    condition = contains([
      "VM.Standard.E4.Flex",
      "VM.Standard.E5.Flex",
      "VM.Standard3.Flex",
      "VM.Optimized3.Flex",
    ], var.monitoring_shape)
    error_message = "Shape must be a supported flexible shape."
  }
}

variable "monitoring_ocpus" {
  description = "Number of OCPUs for Monitoring server instance"
  type        = number
  default     = 4
}

variable "monitoring_memory_in_gbs" {
  description = "Memory in GB for Monitoring server instance"
  type        = number
  default     = 16
}

variable "monitoring_disk_size" {
  description = "Boot volume size in GB for Monitoring server instance"
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
  default     = 2

  validation {
    condition     = var.recording_count >= 0 && var.recording_count <= 20
    error_message = "Recording count must be between 0 and 20."
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
  default     = "VM.Standard.E2.2"

  validation {
    condition = contains([
      "VM.Standard.E2.1",
      "VM.Standard.E2.2",
      "VM.Standard.E2.4",
      "VM.Standard.E2.8",
      "MySQL.2",
      "MySQL.4",
      "MySQL.8",
      "MySQL.16",
      "MySQL.32",
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
  default     = 100

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
