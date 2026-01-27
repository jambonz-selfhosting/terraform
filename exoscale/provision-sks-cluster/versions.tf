terraform {
  required_version = ">= 1.5"

  # Optional: HCP Terraform for remote state
  # cloud {
  #   organization = "jambonz"
  #   workspaces {
  #     name = "jambonz-exoscale-sks"
  #   }
  # }

  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.54"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "exoscale" {
  # Credentials can be provided via:
  # 1. terraform.tfvars (exoscale_api_key, exoscale_api_secret)
  # 2. Environment variables (EXOSCALE_API_KEY, EXOSCALE_API_SECRET)
  #
  # If variables are empty, provider falls back to environment variables
  key    = var.exoscale_api_key != "" ? var.exoscale_api_key : null
  secret = var.exoscale_api_secret != "" ? var.exoscale_api_secret : null
}
