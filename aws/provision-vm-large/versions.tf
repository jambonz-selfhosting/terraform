# Terraform and provider requirements for jambonz large deployment on AWS

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "jambonz"
      Environment = var.name_prefix
      ManagedBy   = "terraform"
    }
  }
}
