################################################################################
# FILE         : modules/iam/variables.tf
# DESCRIPTION  : Input declarations for the IAM module.
#                Provisions EC2 instance roles following least-privilege.
#                No hardcoded ARNs. No wildcard * resources in policies.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# SECTION 1: IDENTITY AND TAGGING
################################################################################

variable "name_prefix" {
  description = "Prefix for all IAM resource names. IAM is global — names must be unique across the entire AWS account, not just a region."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all IAM resources via merge()."
  type        = map(string)
  default     = {}
}

################################################################################
# SECTION 2: CONTEXT
################################################################################

variable "project_name" {
  description = "Project name used to scope IAM policy resource ARNs. Restricts S3 access to project-specific buckets only — not all buckets in the account."
  type        = string
}

variable "environment" {
  description = "Deployment environment. Used to scope resource ARNs in IAM policies so production roles cannot access staging resources and vice versa."
  type        = string
}

variable "aws_region" {
  description = "AWS region. Used to construct full ARNs in IAM policy resource blocks. IAM policies require fully qualified ARNs including region and account ID."
  type        = string
}

################################################################################
# SECTION 3: PERMISSION TOGGLES
# Fine-grained control over what permissions the EC2 role receives.
# In production, only enable what the application actually uses.
################################################################################

variable "enable_s3_access" {
  description = "Grant EC2 instances read access to the project S3 bucket. Required if application reads config files or static assets from S3. Default true — most applications need this."
  type        = bool
  default     = true
}

variable "enable_secrets_manager_access" {
  description = "Grant EC2 instances read access to project secrets in Secrets Manager. Required for applications that retrieve database passwords at runtime. Default true."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_access" {
  description = "Grant EC2 instances permission to publish logs and metrics to CloudWatch. Required for application log shipping and custom metric publishing. Default true."
  type        = bool
  default     = true
}

variable "enable_ssm_access" {
  description = "Grant EC2 instances SSM Session Manager access. Enables SSH-free, audited shell access to instances without opening port 22 or maintaining a Bastion Host. Default true — strongly recommended."
  type        = bool
  default     = true
}
