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
  }
}

provider "exoscale" {
  # Authentication: provide credentials via variables or environment variables
  #
  #   1. Variables: set exoscale_api_key and exoscale_api_secret in your .tfvars file
  #      exoscale_api_key    = "your-api-key"
  #      exoscale_api_secret = "your-api-secret"
  #
  #   2. Environment variables:
  #      export EXOSCALE_API_KEY="your-api-key"
  #      export EXOSCALE_API_SECRET="your-api-secret"
  #
  # Generate credentials in the Exoscale Console:
  #   IAM → API Keys → Create API Key
  key    = var.exoscale_api_key != "" ? var.exoscale_api_key : null
  secret = var.exoscale_api_secret != "" ? var.exoscale_api_secret : null
}
