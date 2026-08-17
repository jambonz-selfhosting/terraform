# Variables for jambonz mini (single VM) deployment on GCP
# All-in-one deployment with local MySQL, Redis, and monitoring

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
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR for the primary subnet"
  type        = string
  default     = "10.0.0.0/24"

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
  description = "CIDR blocks allowed SIP/RTP access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# IMAGE CONFIGURATION
# ------------------------------------------------------------------------------

variable "mini_image" {
  description = "Self-link or name of the mini (all-in-one) server image"
  type        = string
}

# ------------------------------------------------------------------------------
# MACHINE TYPE CONFIGURATION
# ------------------------------------------------------------------------------

variable "machine_type" {
  description = "GCP machine type for the mini server"
  type        = string
  default     = "e2-standard-4"
}

# ------------------------------------------------------------------------------
# DISK SIZE CONFIGURATION
# ------------------------------------------------------------------------------

variable "disk_size" {
  description = "Disk size in GB for the mini instance"
  type        = number
  default     = 100

  validation {
    condition     = var.disk_size >= 100 && var.disk_size <= 1024
    error_message = "Disk size must be between 100 and 1024 GB."
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
