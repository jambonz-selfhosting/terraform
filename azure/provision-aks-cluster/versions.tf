terraform {
  required_version = ">= 1.5"

  # HCP Terraform configuration for remote state
  cloud {
    organization = "jambonz"

    workspaces {
      name = "jambonz-test"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}
