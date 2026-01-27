terraform {
  required_version = ">= 1.0"

  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.54"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

provider "exoscale" {
  # API credentials can be provided via:
  # - Environment variables: EXOSCALE_API_KEY, EXOSCALE_API_SECRET
  # - Or explicitly in terraform.tfvars (not recommended for production)
}
