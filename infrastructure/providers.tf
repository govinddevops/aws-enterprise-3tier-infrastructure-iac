################################################################################
# FILE         : providers.tf
# DESCRIPTION  : AWS Provider configuration with enterprise default_tags,
#                multi-region provider aliases, and assume_role capability
#                for cross-account deployments.
#
# ENTERPRISE STANDARD:
#   The default_tags block is the single source of truth for resource tagging
#   compliance. Every AWS resource provisioned by this configuration inherits
#   these tags automatically — satisfying FinOps, Security, and Audit
#   requirements without any per-resource tag blocks.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# PRIMARY AWS PROVIDER
#
# This is the default provider used by all resources in this project unless
# a resource explicitly specifies 'provider = aws.secondary'.
#
# The region is intentionally driven by a variable — never hardcoded —
# so the same codebase deploys to ap-south-1 (Mumbai) for production
# and us-east-1 for disaster recovery without changing a single line of code.
################################################################################
provider "aws" {

  ##############################################################################
  # REGION CONFIGURATION
  #
  # Driven by var.aws_region defined in variables.tf.
  # Value supplied in terraform.tfvars: "ap-south-1"
  #
  # This pattern means the SAME codebase can target any AWS region simply
  # by changing one value in terraform.tfvars — zero code changes required.
  ##############################################################################
  region = var.aws_region

  ##############################################################################
  # DEFAULT TAGS — ENTERPRISE COMPLIANCE REQUIREMENT
  #
  # These tags are AUTOMATICALLY applied to every single AWS resource that
  # this provider creates — EC2, RDS, S3, Security Groups, Route Tables,
  # everything — without any per-resource tag block needed.
  #
  # WHY THIS MATTERS IN PRODUCTION:
  #   1. COST ALLOCATION  : Finance uses Project + CostCenter to split AWS
  #                         bills across teams and products.
  #   2. SECURITY AUDITS  : Security uses ManagedBy to identify unmanaged
  #                         (manually created) resources that bypass IaC.
  #   3. COMPLIANCE       : Regulators require Environment tags to prove
  #                         production and non-production data are isolated.
  #   4. INCIDENT RESPONSE: On-call engineers use Owner to know who to wake
  #                         up at 3am when something breaks.
  #   5. AUTOMATION       : CI/CD pipelines filter resources by ManagedBy
  #                         = "Terraform" to safely apply automated changes.
  #
  # HOW IT WORKS:
  #   Terraform merges these default_tags with any resource-level tags.
  #   Resource-level tags WIN on conflict (they override the default).
  ##############################################################################
  default_tags {
    tags = {

      # The project identifier — used by FinOps for cost allocation reports.
      # Every AWS bill line item will carry this tag.
      Project = var.project_name

      # The deployment environment — critical for compliance and access control.
      # Allows IAM policies like "deny delete if Environment = Production".
      Environment = var.environment

      # Identifies that this resource was created by Terraform, not manually.
      # Security teams use this to detect and quarantine unmanaged resources.
      ManagedBy = "Terraform"

      # The team responsible for this resource — for incident escalation.
      Owner = var.owner

      # Finance cost-center code — maps AWS spend to internal budget lines.
      CostCenter = var.cost_center

      # The Git repository URL — any engineer finding this resource in the
      # AWS console can immediately locate the code that manages it.
      # This is the IaC equivalent of leaving your name in the code.
      Repository = "aws-enterprise-3tier-infrastructure-iac"

      # Terraform workspace — distinguishes state files across environments
      # when using Terraform workspaces in CI/CD pipelines.
      Workspace = terraform.workspace

    }
  }

}

################################################################################
# SECONDARY AWS PROVIDER — DISASTER RECOVERY REGION
#
# This provider alias targets a second AWS region for disaster recovery (DR)
# resources such as S3 cross-region replication, RDS read replicas, and
# Route 53 health checks.
#
# HOW TO USE THIS IN A RESOURCE:
#   resource "aws_s3_bucket" "dr_bucket" {
#     provider = aws.secondary    # <-- this targets the DR region
#     bucket   = "my-dr-bucket"
#   }
#
# ENTERPRISE CONTEXT:
#   In a real production setup, this would target us-west-2 or eu-west-1
#   as the DR region. For this Free Tier project, it is declared here to
#   demonstrate the pattern — not actively used until the DR module is added.
#
# NOTE FOR FREE TIER:
#   Having a secondary provider declared does NOT create any resources or
#   incur any cost. Resources are only created when a resource block
#   explicitly references 'provider = aws.secondary'.
################################################################################
provider "aws" {
  alias  = "secondary"
  region = var.aws_secondary_region
}
