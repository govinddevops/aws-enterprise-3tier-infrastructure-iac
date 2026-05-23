################################################################################
# FILE         : bootstrap/variables.tf
# DESCRIPTION  : Input variables for the bootstrap module.
#                Kept intentionally minimal — bootstrap creates only the
#                S3 state bucket and DynamoDB lock table.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

variable "aws_region" {
  description = "AWS region where the S3 state bucket and DynamoDB lock table will be created. Should match the primary region used by the root module."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "aws_region must be a valid AWS region format, e.g. ap-south-1."
  }
}

variable "project_name" {
  description = "Project name used as a prefix in the S3 bucket and DynamoDB table names. Must be lowercase alphanumeric with hyphens only."
  type        = string
  default     = "enterprise-3tier"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment identifier appended to resource names. Helps distinguish bootstrap resources across multiple deployments."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}
