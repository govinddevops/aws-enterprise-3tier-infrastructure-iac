################################################################################
# FILE         : versions.tf
# DESCRIPTION  : Terraform core version constraint and required provider
#                declarations for the AWS Enterprise 3-Tier Infrastructure.
#
# ENTERPRISE STANDARD:
#   Version pinning using pessimistic constraint operators (~>) ensures
#   this codebase behaves identically across all execution environments —
#   local workstations, CI/CD pipelines, and teammate machines.
#   This is a non-negotiable compliance requirement in production IaC.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

terraform {

  ##############################################################################
  # TERRAFORM CORE VERSION CONSTRAINT
  #
  # ~> 1.6 means:
  #   ALLOWED  : 1.6.0, 1.6.1, 1.6.14, 1.9.x, 1.10.x  (any 1.x above 1.6)
  #   BLOCKED  : 0.x, 2.x  (major version changes = breaking changes)
  #
  # WHY 1.6+:
  #   Terraform 1.6 introduced the 'test' framework for native IaC unit
  #   testing — a hard requirement for enterprise-grade CI/CD pipelines.
  ##############################################################################
  required_version = "~> 1.6"

  ##############################################################################
  # REQUIRED PROVIDERS BLOCK
  #
  # Declaring providers here (rather than letting Terraform auto-detect them)
  # gives us:
  #   1. Explicit source registry control (prevents supply-chain attacks)
  #   2. Version pinning at the provider level (not just core)
  #   3. Faster 'terraform init' (no registry discovery needed)
  ##############################################################################
  required_providers {

    ##--------------------------------------------------------------------------
    # AWS PROVIDER
    #
    # Source  : registry.terraform.io/hashicorp/aws
    # Version : ~> 5.0 means any 5.x release (5.0, 5.1 ... 5.99)
    #           but NOT 6.x which would introduce breaking changes.
    #
    # AWS Provider 5.x key enterprise features used in this project:
    #   - Native default_tags propagation to all resources
    #   - IMDSv2 enforcement on EC2 instances
    #   - Enhanced RDS Blue/Green deployment support
    #   - Refined IAM policy document validation
    ##--------------------------------------------------------------------------
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    ##--------------------------------------------------------------------------
    # RANDOM PROVIDER
    #
    # Used to generate unique suffixes for globally-unique resource names
    # such as S3 bucket names (which must be unique across ALL AWS accounts
    # worldwide). This eliminates hardcoded names and naming collisions.
    #
    # Example usage in this project:
    #   - S3 state bucket : "enterprise-tfstate-a3f8c2d1"
    #   - RDS identifier  : "enterprise-db-k9m2p7"
    ##--------------------------------------------------------------------------
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

  }

}
