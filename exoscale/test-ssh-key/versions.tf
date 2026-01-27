terraform {
  required_version = ">= 1.0"

  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.54"
    }
  }
}

provider "exoscale" {
  # Use environment variables: EXOSCALE_API_KEY, EXOSCALE_API_SECRET
}
