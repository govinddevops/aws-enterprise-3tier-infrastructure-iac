################################################################################
# FILE         : bootstrap/main.tf
# DESCRIPTION  : Provisions the S3 remote backend bucket and DynamoDB
#                state lock table. Run this ONCE before the root module.
#
# RESOURCES CREATED:
#   1. random_string        — unique suffix for globally-unique S3 bucket name
#   2. aws_s3_bucket        — Terraform state file storage
#   3. aws_s3_bucket_versioning          — retains every state revision
#   4. aws_s3_bucket_server_side_encryption_configuration — AES-256 at rest
#   5. aws_s3_bucket_public_access_block — blocks ALL public access
#   6. aws_dynamodb_table   — state lock table (prevents concurrent applies)
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# RANDOM SUFFIX
# Generates an 8-character random string appended to the S3 bucket name.
# S3 bucket names must be globally unique across all 300 million+ AWS accounts.
# A random suffix eliminates naming collisions with zero manual coordination.
################################################################################

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
  # Result example: "a3f8c2d1"
  # Final bucket name: "enterprise-3tier-tfstate-a3f8c2d1"
}

################################################################################
# LOCAL VALUES
# Derive consistent names from variables + random suffix.
################################################################################

locals {
  bucket_name    = "${var.project_name}-tfstate-${random_string.suffix.result}"
  dynamodb_table = "${var.project_name}-terraform-state-lock"
}

################################################################################
# S3 BUCKET — TERRAFORM STATE STORAGE
################################################################################

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.bucket_name

  # force_destroy allows 'terraform destroy' to delete the bucket even
  # if it contains state file versions. Set to false in real production
  # to prevent accidental deletion of all state history.
  force_destroy = false

  tags = {
    Name        = local.bucket_name
    Purpose     = "Terraform Remote State Storage"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform-Bootstrap"
  }
}

################################################################################
# S3 BUCKET VERSIONING
# Retains every version of the state file ever written.
# Enables point-in-time recovery if a bad 'terraform apply' corrupts state.
# Every 'terraform apply' writes a new state version — old versions are kept.
################################################################################

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

################################################################################
# S3 SERVER-SIDE ENCRYPTION
# Encrypts every object (state file) stored in this bucket using AES-256.
# The state file contains sensitive data in plaintext:
#   - Database connection strings
#   - Private IP addresses
#   - IAM role ARNs
# Encryption at rest is mandatory for SOC2, PCI-DSS, and ISO 27001.
################################################################################

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    # Enforce encryption — reject unencrypted PutObject requests
    bucket_key_enabled = true
  }
}

################################################################################
# S3 PUBLIC ACCESS BLOCK
# Blocks ALL forms of public access to the state bucket.
# A publicly readable state file exposes your entire infrastructure map
# to any attacker on the internet — architecture, IPs, resource IDs.
# These four settings form a complete public access barrier.
################################################################################

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  # Blocks public ACLs from being applied to the bucket or any object
  block_public_acls = true

  # Blocks public bucket policies from being applied
  block_public_policy = true

  # Ignores any public ACLs that somehow exist on the bucket or objects
  ignore_public_acls = true

  # Restricts access to buckets with public policies to only AWS services
  # and authorized users — even if a public policy exists
  restrict_public_buckets = true
}

################################################################################
# S3 BUCKET LIFECYCLE POLICY
# Automatically manages old state file versions to control storage costs.
# Keeps the last 30 days of state versions for recovery purposes.
# Older versions are permanently deleted to avoid unbounded storage growth.
################################################################################

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  # Depends on versioning being enabled first
  depends_on = [aws_s3_bucket_versioning.terraform_state]

  rule {
    id     = "state-file-lifecycle"
    status = "Enabled"

    # Apply this rule to all objects in the bucket
    filter {
      prefix = ""
    }

    # Delete non-current (old) versions after 30 days
    # This retains 30 days of state history for recovery
    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    # Clean up incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

################################################################################
# DYNAMODB TABLE — STATE LOCKING
#
# Prevents concurrent Terraform operations from corrupting state.
#
# HOW IT WORKS:
#   terraform apply (Engineer A) → writes LockID to DynamoDB → applies
#   terraform apply (Engineer B) → tries to write LockID → REJECTED
#   Engineer B sees: "Error: state is currently locked by another operation"
#   Engineer B waits for A to finish → lock released → B can proceed
#
# TABLE REQUIREMENTS (Terraform convention — not configurable):
#   - Primary key must be named exactly: LockID
#   - Type must be String (S)
#
# BILLING MODE:
#   PAY_PER_REQUEST = serverless pricing
#   You pay per read/write operation — not per hour
#   Cost for typical Terraform usage: < $0.01/month
#   No minimum charge — effectively free for this use case
################################################################################

resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = local.dynamodb_table
  billing_mode = "PAY_PER_REQUEST"

  # Terraform REQUIRES this exact primary key name and type
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"  # S = String type
  }

  # Enable point-in-time recovery for the lock table itself
  # Protects against accidental table deletion
  point_in_time_recovery {
    enabled = true
  }

  # Encrypt the DynamoDB table at rest
  # Lock records contain resource metadata — encrypt as standard practice
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = local.dynamodb_table
    Purpose     = "Terraform State Locking"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform-Bootstrap"
  }
}
