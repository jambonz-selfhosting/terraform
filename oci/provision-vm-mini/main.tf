# Terraform configuration for jambonz mini deployment on Oracle Cloud Infrastructure (OCI)

terraform {
  required_version = ">= 1.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# ------------------------------------------------------------------------------
# DATA SOURCES
# ------------------------------------------------------------------------------

# Get availability domain
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_number - 1].name
}

# ------------------------------------------------------------------------------
# RANDOM SECRETS
# ------------------------------------------------------------------------------

# Generate JWT secret
# No special characters to avoid sed escaping issues in cloud-init
resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

# Generate database password
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

# ------------------------------------------------------------------------------
# VIRTUAL CLOUD NETWORK (VCN)
# ------------------------------------------------------------------------------

resource "oci_core_vcn" "jambonz" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.name_prefix}-vcn"
  dns_label      = replace(var.name_prefix, "-", "")

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
    deployment  = "mini"
  }
}

# ------------------------------------------------------------------------------
# INTERNET GATEWAY
# ------------------------------------------------------------------------------

resource "oci_core_internet_gateway" "jambonz" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.jambonz.id
  display_name   = "${var.name_prefix}-igw"
  enabled        = true

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# ------------------------------------------------------------------------------
# ROUTE TABLE
# ------------------------------------------------------------------------------

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.jambonz.id
  display_name   = "${var.name_prefix}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.jambonz.id
  }

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
  }
}

# ------------------------------------------------------------------------------
# PUBLIC SUBNET
# ------------------------------------------------------------------------------

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.jambonz.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${var.name_prefix}-public-subnet"
  dns_label                  = "public"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_vcn.jambonz.default_security_list_id]

  freeform_tags = {
    environment = var.environment
    service     = "jambonz"
  }
}
