################################################################################
# FILE         : bootstrap/outputs.tf
# DESCRIPTION  : Outputs the S3 bucket name and DynamoDB table name generated
#                by the bootstrap module. Copy these values directly into
#                the root backend.tf before running 'terraform init'.
#
# USAGE AFTER BOOTSTRAP APPLY:
#   terraform output s3_bucket_name
#   terraform output dynamodb_table_name
#   terraform output backend_config_block
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# S3 BUCKET OUTPUTS
################################################################################

output "s3_bucket_name" {
  description = "The globally unique name of the S3 bucket storing Terraform state. Copy this exact value into the 'bucket' field of backend.tf in the root module."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "s3_bucket_arn" {
  description = "The ARN of the Terraform state S3 bucket. Use this in IAM policies to grant specific IAM users or roles access to read and write state."
  value       = aws_s3_bucket.terraform_state.arn
}

output "s3_bucket_region" {
  description = "The AWS region where the S3 state bucket was created. Must match the 'region' field in backend.tf."
  value       = aws_s3_bucket.terraform_state.region
}

################################################################################
# DYNAMODB TABLE OUTPUTS
################################################################################

output "dynamodb_table_name" {
  description = "The name of the DynamoDB state lock table. Copy this exact value into the 'dynamodb_table' field of backend.tf in the root module."
  value       = aws_dynamodb_table.terraform_state_lock.name
}

output "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB lock table. Use this in IAM policies to grant PutItem, GetItem, and DeleteItem permissions for state locking."
  value       = aws_dynamodb_table.terraform_state_lock.arn
}

################################################################################
# CONVENIENCE OUTPUT
# Prints the complete backend block ready to paste into backend.tf.
# After bootstrap apply, run: terraform output backend_config_block
# Then copy the printed block directly into root backend.tf.
################################################################################

output "backend_config_block" {
  description = "Complete backend configuration block. Copy this entire output and replace the backend block in root backend.tf. Then run 'terraform init' in the root module."
  value       = <<-EOT

    ############################################################
    # PASTE THIS INTO root backend.tf — replacing the existing
    # backend "s3" block content
    ############################################################

    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.bucket}"
      key            = "aws-enterprise-3tier/prod/terraform.tfstate"
      region         = "${aws_s3_bucket.terraform_state.region}"
      encrypt        = true
      dynamodb_table = "${aws_dynamodb_table.terraform_state_lock.name}"
    }

  EOT
}

################################################################################
# NEXT STEPS OUTPUT
# Prints the exact commands to run after bootstrap apply completes.
################################################################################

output "next_steps" {
  description = "Step-by-step instructions to complete backend migration after bootstrap apply."
  value       = <<-EOT

    ============================================================
    BOOTSTRAP COMPLETE — NEXT STEPS:
    ============================================================

    1. Copy the bucket name:
       ${aws_s3_bucket.terraform_state.bucket}

    2. Update root backend.tf:
       Replace 'enterprise-tfstate-REPLACE-AFTER-BOOTSTRAP'
       with the bucket name above.

    3. Initialise the root module with S3 backend:
       cd ..
       terraform init

    4. Verify backend migration succeeded:
       terraform state list
       (Should show empty state — ready for first apply)

    ============================================================

  EOT
}
