# Variables for jambonz large cluster deployment on GCP
# Fully separated architecture: Web, Monitoring, SIP, RTP as individual VMs

# ------------------------------------------------------------------------------
# GCP PROJECT CONFIGURATION
# ------------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region to deploy in"
  type        = string
}

variable "zone" {
  description = "GCP zone for zonal resources"
  type        = string
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

variable "public_subnet_cidr" {
  description = "CIDR for the primary subnet"
  type        = string
  default     = "172.20.10.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
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

variable "allowed_sip_cidr" {
  description = "CIDR blocks allowed SIP access to SIP servers"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_rtp_cidr" {
  description = "CIDR blocks allowed RTP access to RTP servers"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# IMAGE CONFIGURATION
# ------------------------------------------------------------------------------

variable "sip_image" {
  description = "Self-link or name of the SIP server image"
  type        = string
  # An arm64 deployment needs arm64 images, an arm machine family and (for c4a)
  # a hyperdisk boot disk to agree. GCP images declare their own architecture, so
  # a mismatch IS rejected -- but only when the instance is created, part-way
  # through apply, once the network, database and other hosts already exist.
  # These move that failure to plan time.
  validation {
    condition = var.sip_image == "" ? true : (
      can(regex("arm64", var.sip_image)) == can(regex("^(c4a|t2a)-", var.sip_machine_type))
    )
    error_message = "Architecture mismatch: sip_image and sip_machine_type must target the same architecture. An arm64 image needs a c4a-* or t2a-* machine type; an amd64 image needs an x86 type (e2-*, n2-*, c3-*)."
  }

  validation {
    condition = var.sip_image == "" ? true : (
      !can(regex("^c4a-", var.sip_machine_type)) || can(regex("^hyperdisk", var.disk_type))
    )
    error_message = "sip_machine_type is c4a-* (Axion), which does not support pd-* disks at all. Set disk_type = \"hyperdisk-balanced\" -- the arm64 example file does this. Without it the instance cannot boot."
  }

}

variable "rtp_image" {
  description = "Self-link or name of the RTP server image"
  type        = string
  # An arm64 deployment needs arm64 images, an arm machine family and (for c4a)
  # a hyperdisk boot disk to agree. GCP images declare their own architecture, so
  # a mismatch IS rejected -- but only when the instance is created, part-way
  # through apply, once the network, database and other hosts already exist.
  # These move that failure to plan time.
  validation {
    condition = var.rtp_image == "" ? true : (
      can(regex("arm64", var.rtp_image)) == can(regex("^(c4a|t2a)-", var.rtp_machine_type))
    )
    error_message = "Architecture mismatch: rtp_image and rtp_machine_type must target the same architecture. An arm64 image needs a c4a-* or t2a-* machine type; an amd64 image needs an x86 type (e2-*, n2-*, c3-*)."
  }

  validation {
    condition = var.rtp_image == "" ? true : (
      !can(regex("^c4a-", var.rtp_machine_type)) || can(regex("^hyperdisk", var.disk_type))
    )
    error_message = "rtp_machine_type is c4a-* (Axion), which does not support pd-* disks at all. Set disk_type = \"hyperdisk-balanced\" -- the arm64 example file does this. Without it the instance cannot boot."
  }

}

variable "web_image" {
  description = "Self-link or name of the Web server image"
  type        = string
  # An arm64 deployment needs arm64 images, an arm machine family and (for c4a)
  # a hyperdisk boot disk to agree. GCP images declare their own architecture, so
  # a mismatch IS rejected -- but only when the instance is created, part-way
  # through apply, once the network, database and other hosts already exist.
  # These move that failure to plan time.
  validation {
    condition = var.web_image == "" ? true : (
      can(regex("arm64", var.web_image)) == can(regex("^(c4a|t2a)-", var.web_machine_type))
    )
    error_message = "Architecture mismatch: web_image and web_machine_type must target the same architecture. An arm64 image needs a c4a-* or t2a-* machine type; an amd64 image needs an x86 type (e2-*, n2-*, c3-*)."
  }

  validation {
    condition = var.web_image == "" ? true : (
      !can(regex("^c4a-", var.web_machine_type)) || can(regex("^hyperdisk", var.disk_type))
    )
    error_message = "web_machine_type is c4a-* (Axion), which does not support pd-* disks at all. Set disk_type = \"hyperdisk-balanced\" -- the arm64 example file does this. Without it the instance cannot boot."
  }

}

variable "monitoring_image" {
  description = "Self-link or name of the Monitoring server image"
  type        = string
  # An arm64 deployment needs arm64 images, an arm machine family and (for c4a)
  # a hyperdisk boot disk to agree. GCP images declare their own architecture, so
  # a mismatch IS rejected -- but only when the instance is created, part-way
  # through apply, once the network, database and other hosts already exist.
  # These move that failure to plan time.
  validation {
    condition = var.monitoring_image == "" ? true : (
      can(regex("arm64", var.monitoring_image)) == can(regex("^(c4a|t2a)-", var.monitoring_machine_type))
    )
    error_message = "Architecture mismatch: monitoring_image and monitoring_machine_type must target the same architecture. An arm64 image needs a c4a-* or t2a-* machine type; an amd64 image needs an x86 type (e2-*, n2-*, c3-*)."
  }

  validation {
    condition = var.monitoring_image == "" ? true : (
      !can(regex("^c4a-", var.monitoring_machine_type)) || can(regex("^hyperdisk", var.disk_type))
    )
    error_message = "monitoring_machine_type is c4a-* (Axion), which does not support pd-* disks at all. Set disk_type = \"hyperdisk-balanced\" -- the arm64 example file does this. Without it the instance cannot boot."
  }

}

variable "feature_server_image" {
  description = "Self-link or name of the Feature Server image"
  type        = string
  # An arm64 deployment needs arm64 images, an arm machine family and (for c4a)
  # a hyperdisk boot disk to agree. GCP images declare their own architecture, so
  # a mismatch IS rejected -- but only when the instance is created, part-way
  # through apply, once the network, database and other hosts already exist.
  # These move that failure to plan time.
  validation {
    condition = var.feature_server_image == "" ? true : (
      can(regex("arm64", var.feature_server_image)) == can(regex("^(c4a|t2a)-", var.feature_server_machine_type))
    )
    error_message = "Architecture mismatch: feature_server_image and feature_server_machine_type must target the same architecture. An arm64 image needs a c4a-* or t2a-* machine type; an amd64 image needs an x86 type (e2-*, n2-*, c3-*)."
  }

  validation {
    condition = var.feature_server_image == "" ? true : (
      !can(regex("^c4a-", var.feature_server_machine_type)) || can(regex("^hyperdisk", var.disk_type))
    )
    error_message = "feature_server_machine_type is c4a-* (Axion), which does not support pd-* disks at all. Set disk_type = \"hyperdisk-balanced\" -- the arm64 example file does this. Without it the instance cannot boot."
  }

}

variable "recording_image" {
  description = "Self-link or name of the Recording Server image"
  type        = string
  default     = ""

  # deploy_recording_cluster defaults to true, so a deployment that never sets
  # recording_image reaches `terraform apply` with source_image = "". plan
  # SUCCEEDS in that state -- it is a valid empty string -- and the failure only
  # lands mid-apply when the GCP API rejects an image with no source, by which
  # point ~35 other resources exist and have to be torn down by hand. Fail here
  # instead, at plan time, with a message that says what to do.
  validation {
    condition     = !var.deploy_recording_cluster || length(trimspace(var.recording_image)) > 0
    error_message = "recording_image must be set when deploy_recording_cluster is true (the default). Supply the jambonz recording image, e.g. projects/drachtio-cpaas/global/images/jambonz-recording-<version>-debian-12-amd64-<ts>, or set deploy_recording_cluster = false to skip the recording cluster."
  }
  # An arm64 deployment needs arm64 images, an arm machine family and (for c4a)
  # a hyperdisk boot disk to agree. GCP images declare their own architecture, so
  # a mismatch IS rejected -- but only when the instance is created, part-way
  # through apply, once the network, database and other hosts already exist.
  # These move that failure to plan time.
  validation {
    condition = var.recording_image == "" ? true : (
      can(regex("arm64", var.recording_image)) == can(regex("^(c4a|t2a)-", var.recording_machine_type))
    )
    error_message = "Architecture mismatch: recording_image and recording_machine_type must target the same architecture. An arm64 image needs a c4a-* or t2a-* machine type; an amd64 image needs an x86 type (e2-*, n2-*, c3-*)."
  }

  validation {
    condition = var.recording_image == "" ? true : (
      !can(regex("^c4a-", var.recording_machine_type)) || can(regex("^hyperdisk", var.disk_type))
    )
    error_message = "recording_machine_type is c4a-* (Axion), which does not support pd-* disks at all. Set disk_type = \"hyperdisk-balanced\" -- the arm64 example file does this. Without it the instance cannot boot."
  }

}

# ------------------------------------------------------------------------------
# MACHINE TYPE CONFIGURATION
# ------------------------------------------------------------------------------

variable "sip_machine_type" {
  description = "GCP machine type for SIP servers"
  type        = string
  default     = "e2-standard-2"
}

variable "rtp_machine_type" {
  description = "GCP machine type for RTP servers"
  type        = string
  default     = "e2-standard-2"
}

variable "web_machine_type" {
  description = "GCP machine type for Web server"
  type        = string
  default     = "e2-standard-4"
}

variable "monitoring_machine_type" {
  description = "GCP machine type for Monitoring server"
  type        = string
  default     = "e2-standard-4"
}

variable "feature_server_machine_type" {
  description = "GCP machine type for Feature Servers"
  type        = string
  default     = "e2-standard-4"
}

variable "recording_machine_type" {
  description = "GCP machine type for Recording Servers"
  type        = string
  default     = "e2-standard-2"
}

# ------------------------------------------------------------------------------
# DISK SIZE CONFIGURATION
# ------------------------------------------------------------------------------

variable "sip_disk_size" {
  description = "Disk size in GB for SIP instances"
  type        = number
  default     = 100

  validation {
    condition     = var.sip_disk_size >= 100 && var.sip_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "rtp_disk_size" {
  description = "Disk size in GB for RTP instances"
  type        = number
  default     = 100

  validation {
    condition     = var.rtp_disk_size >= 100 && var.rtp_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "web_disk_size" {
  description = "Disk size in GB for Web server"
  type        = number
  default     = 100

  validation {
    condition     = var.web_disk_size >= 100 && var.web_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "monitoring_disk_size" {
  description = "Disk size in GB for Monitoring server (larger for time-series data)"
  type        = number
  default     = 200

  validation {
    condition     = var.monitoring_disk_size >= 100 && var.monitoring_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "feature_server_disk_size" {
  description = "Disk size in GB for Feature Server instances"
  type        = number
  default     = 100

  validation {
    condition     = var.feature_server_disk_size >= 100 && var.feature_server_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

variable "recording_disk_size" {
  description = "Disk size in GB for Recording Server instances"
  type        = number
  default     = 100

  validation {
    condition     = var.recording_disk_size >= 100 && var.recording_disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
  }
}

# ------------------------------------------------------------------------------
# SIP/RTP INSTANCE COUNTS
# ------------------------------------------------------------------------------

variable "sip_count" {
  description = "Number of SIP server instances to deploy (each gets a static public IP)"
  type        = number
  default     = 1

  validation {
    condition     = var.sip_count >= 1 && var.sip_count <= 10
    error_message = "SIP count must be between 1 and 10."
  }
}

variable "rtp_count" {
  description = "Number of RTP server instances to deploy (each gets a static public IP)"
  type        = number
  default     = 1

  validation {
    condition     = var.rtp_count >= 1 && var.rtp_count <= 10
    error_message = "RTP count must be between 1 and 10."
  }
}

# ------------------------------------------------------------------------------
# MANAGED INSTANCE GROUP CONFIGURATION
# ------------------------------------------------------------------------------

variable "feature_server_target_size" {
  description = "Target number of Feature Server instances"
  type        = number
  default     = 1
}

variable "feature_server_min_replicas" {
  description = "Minimum number of Feature Server instances"
  type        = number
  default     = 1
}

variable "feature_server_max_replicas" {
  description = "Maximum number of Feature Server instances"
  type        = number
  default     = 8
}

variable "recording_target_size" {
  description = "Target number of Recording Server instances"
  type        = number
  default     = 1
}

variable "recording_min_replicas" {
  description = "Minimum number of Recording Server instances"
  type        = number
  default     = 1
}

variable "recording_max_replicas" {
  description = "Maximum number of Recording Server instances"
  type        = number
  default     = 8
}

# Graceful scale-in timeout (max 15 minutes)
variable "scale_in_timeout_seconds" {
  description = "Time to wait for graceful shutdown during scale-in (max 900 seconds / 15 minutes)"
  type        = number
  default     = 900

  validation {
    condition     = var.scale_in_timeout_seconds >= 60 && var.scale_in_timeout_seconds <= 900
    error_message = "Scale-in timeout must be between 60 and 900 seconds."
  }
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
  default     = "jambonz"
}

variable "mysql_password" {
  description = "MySQL admin password (leave empty to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "mysql_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-custom-2-4096"
}

variable "mysql_disk_size" {
  description = "Cloud SQL disk size in GB"
  type        = number
  default     = 20
}

# ------------------------------------------------------------------------------
# REDIS CONFIGURATION (Memorystore)
# ------------------------------------------------------------------------------

variable "redis_memory_size_gb" {
  description = "Redis memory size in GB"
  type        = number
  default     = 1
}

variable "redis_tier" {
  description = "Redis tier (BASIC or STANDARD_HA)"
  type        = string
  default     = "BASIC"

  validation {
    condition     = contains(["BASIC", "STANDARD_HA"], var.redis_tier)
    error_message = "Redis tier must be BASIC or STANDARD_HA."
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

variable "deploy_recording_cluster" {
  description = "Deploy the recording server cluster"
  type        = bool
  default     = true
}

variable "feature_server_public_ip" {
  description = "Assign public IPs to Feature Server instances (false = use Cloud NAT for outbound)"
  type        = bool
  default     = false
}

variable "krisp_license_key" {
  description = "Krisp license key for noise isolation and turn-taking (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "disk_type" {
  description = <<-EOT
    Boot disk type for every jambonz VM in this deployment.

    Leave at pd-ssd for x86 (e2/n2/c3) machine types. The arm64 Axion family
    (c4a-*) does NOT support pd-* disks at all and requires Hyperdisk, so an
    arm64 deployment must set this to hyperdisk-balanced alongside arm64
    machine types and arm64 images. t2a-* (the older Ampere arm family) does
    accept pd-ssd, but it is region-limited and superseded by c4a.
  EOT
  type        = string
  default     = "pd-ssd"

  validation {
    condition     = contains(["pd-ssd", "pd-balanced", "pd-standard", "hyperdisk-balanced"], var.disk_type)
    error_message = "disk_type must be one of pd-ssd, pd-balanced, pd-standard, hyperdisk-balanced."
  }
}
