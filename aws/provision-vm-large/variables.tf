# Variables for jambonz large (fully separated) deployment on AWS
# SIP, RTP, Feature Server, Web, Monitoring as separate VMs with managed Aurora and ElastiCache

# ------------------------------------------------------------------------------
# AWS CONFIGURATION
# ------------------------------------------------------------------------------

variable "region" {
  description = "AWS region to deploy in"
  type        = string
  default     = "us-east-1"
}

# ------------------------------------------------------------------------------
# DEPLOYMENT CONFIGURATION
# ------------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "jambonz"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "Name prefix must be lowercase alphanumeric with hyphens, start with a letter, and be 2-21 characters."
  }
}

variable "environment" {
  description = "Environment label (e.g., production, staging, dev)"
  type        = string
  default     = "production"
}

# ------------------------------------------------------------------------------
# NETWORK CONFIGURATION
# ------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR range for the VPC"
  type        = string
  default     = "172.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the two public subnets (one per AZ)"
  type        = list(string)
  default     = ["172.20.10.0/24", "172.20.11.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for the two private subnets (for Aurora and ElastiCache)"
  type        = list(string)
  default     = ["172.20.20.0/24", "172.20.21.0/24"]
}

# ------------------------------------------------------------------------------
# NETWORK ACCESS CONTROLS
# ------------------------------------------------------------------------------

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_http_cidr" {
  description = "CIDR blocks allowed HTTP/HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_sbc_cidr" {
  description = "CIDR blocks allowed SIP/RTP access to SBC servers"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# INSTANCE CONFIGURATION
# ------------------------------------------------------------------------------

variable "sip_instance_type" {
  description = "EC2 instance type for SIP servers"
  type        = string
  default     = "c5n.xlarge"
}

variable "rtp_instance_type" {
  description = "EC2 instance type for RTP servers"
  type        = string
  default     = "c5n.xlarge"
}

variable "feature_server_instance_type" {
  description = "EC2 instance type for Feature Servers"
  type        = string
  default     = "c5n.xlarge"
}

variable "web_instance_type" {
  description = "EC2 instance type for Web server"
  type        = string
  default     = "c5n.xlarge"
}

variable "monitoring_instance_type" {
  description = "EC2 instance type for Monitoring server"
  type        = string
  default     = "c5n.xlarge"
}

variable "recording_instance_type" {
  description = "EC2 instance type for Recording Servers"
  type        = string
  default     = "t3.xlarge"
}

# ------------------------------------------------------------------------------
# DISK SIZE CONFIGURATION
# ------------------------------------------------------------------------------

variable "sip_disk_size" {
  description = "Root volume size in GB for SIP servers"
  type        = number
  default     = 100

  validation {
    condition     = var.sip_disk_size >= 100 && var.sip_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "rtp_disk_size" {
  description = "Root volume size in GB for RTP servers"
  type        = number
  default     = 100

  validation {
    condition     = var.rtp_disk_size >= 100 && var.rtp_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "feature_server_disk_size" {
  description = "Root volume size in GB for Feature Servers"
  type        = number
  default     = 100

  validation {
    condition     = var.feature_server_disk_size >= 100 && var.feature_server_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "web_disk_size" {
  description = "Root volume size in GB for Web server"
  type        = number
  default     = 100

  validation {
    condition     = var.web_disk_size >= 100 && var.web_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "monitoring_disk_size" {
  description = "Root volume size in GB for Monitoring server"
  type        = number
  default     = 200

  validation {
    condition     = var.monitoring_disk_size >= 100 && var.monitoring_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "recording_disk_size" {
  description = "Root volume size in GB for Recording Servers"
  type        = number
  default     = 100

  validation {
    condition     = var.recording_disk_size >= 100 && var.recording_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

# ------------------------------------------------------------------------------
# INSTANCE COUNTS
# ------------------------------------------------------------------------------

variable "sip_count" {
  description = "Number of SIP server instances"
  type        = number
  default     = 1

  validation {
    condition     = var.sip_count >= 1 && var.sip_count <= 10
    error_message = "SIP count must be between 1 and 10."
  }
}

variable "rtp_count" {
  description = "Number of RTP server instances"
  type        = number
  default     = 1

  validation {
    condition     = var.rtp_count >= 1 && var.rtp_count <= 10
    error_message = "RTP count must be between 1 and 10."
  }
}

# ------------------------------------------------------------------------------
# FEATURE SERVER AUTO SCALING
# ------------------------------------------------------------------------------

variable "feature_server_min_size" {
  description = "Minimum number of Feature Server instances"
  type        = number
  default     = 1
}

variable "feature_server_max_size" {
  description = "Maximum number of Feature Server instances"
  type        = number
  default     = 8
}

variable "feature_server_desired_capacity" {
  description = "Desired number of Feature Server instances"
  type        = number
  default     = 1
}

# ------------------------------------------------------------------------------
# RECORDING AUTO SCALING
# ------------------------------------------------------------------------------

variable "recording_min_size" {
  description = "Minimum number of Recording Server instances"
  type        = number
  default     = 1
}

variable "recording_max_size" {
  description = "Maximum number of Recording Server instances"
  type        = number
  default     = 8
}

variable "recording_desired_capacity" {
  description = "Desired number of Recording Server instances"
  type        = number
  default     = 1
}

# ------------------------------------------------------------------------------
# SSH CONFIGURATION
# ------------------------------------------------------------------------------

variable "ssh_public_key" {
  description = "SSH public key content for VM access"
  type        = string
}

variable "ssh_user" {
  description = "SSH username"
  type        = string
  default     = "jambonz"
}

# ------------------------------------------------------------------------------
# DATABASE CONFIGURATION
# ------------------------------------------------------------------------------

variable "mysql_username" {
  description = "MySQL admin username"
  type        = string
  default     = "admin"
}

variable "mysql_password" {
  description = "MySQL admin password (leave empty to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aurora_min_capacity" {
  description = "Aurora Serverless v2 minimum ACU capacity"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Aurora Serverless v2 maximum ACU capacity"
  type        = number
  default     = 8
}

# ------------------------------------------------------------------------------
# REDIS CONFIGURATION
# ------------------------------------------------------------------------------

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.medium"
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

variable "enable_pcaps" {
  description = "Enable SIP/RTP packet capture (PCAP) to Homer"
  type        = bool
  default     = true
}

variable "deploy_recording_cluster" {
  description = "Deploy optional recording server cluster behind ALB"
  type        = bool
  default     = true
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
