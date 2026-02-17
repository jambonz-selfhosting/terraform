terraform {
  required_version = ">= 1.5"

  # Optional: HCP Terraform for remote state
  # cloud {
  #   organization = "jambonz"
  #   workspaces {
  #     name = "jambonz-aws-eks"
  #   }
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region

  # Credentials can be provided via:
  # 1. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
  # 2. AWS credentials file (~/.aws/credentials)
  # 3. IAM role (when running on EC2/ECS/Lambda)

  default_tags {
    tags = {
      Project     = "jambonz"
      Environment = var.name_prefix
      ManagedBy   = "terraform"
    }
  }
}

# Kubernetes provider for creating storage class
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
  }
}
