terraform {
  required_version = ">= 1.5"

  cloud {
    organization = "jambonz"
    workspaces {
      name = "jambonz-test"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
