################################################################################
# FILE         : bootstrap/versions.tf
# DESCRIPTION  : Version constraints for the bootstrap module.
#                This module uses a LOCAL backend intentionally — it runs
#                BEFORE the S3 backend exists. It is the only module in
#                this project that is permitted to use local state.
#
# RUN ORDER:
#   1. cd bootstrap && terraform init && terraform apply
#   2. Copy S3 bucket name from output into root backend.tf
#   3. cd .. && terraform init && terraform apply
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

terraform {

  # Local backend — intentional and correct for bootstrap only.
  # The state file for bootstrap lives locally at bootstrap/terraform.tfstate
  # This is acceptable because bootstrap creates only 2 resources
  # that almost never change after initial setup.
  backend "local" {
    path = "terraform.tfstate"
  }

  required_version = "~> 1.6"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Random provider generates a unique suffix for the S3 bucket name.
    # S3 bucket names are globally unique across ALL AWS accounts worldwide.
    # A random suffix eliminates naming collisions with zero manual effort.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

  }

}

################################################################################
# BOOTSTRAP AWS PROVIDER
# Minimal provider — no default_tags needed here.
# Bootstrap creates only 2 infrastructure resources (S3 + DynamoDB).
################################################################################

provider "aws" {
  region = var.aws_region
}
