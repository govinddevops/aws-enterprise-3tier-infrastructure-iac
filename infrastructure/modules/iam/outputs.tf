################################################################################
# FILE         : modules/iam/outputs.tf
# DESCRIPTION  : Exports IAM resource identifiers for the Compute module
#                and for cross-service policy references.
#
# CONSUMED BY:
#   compute module → instance_profile_name (attached to Launch Template)
#   s3 policies    → ec2_role_arn          (bucket policy principal)
#   kms policies   → ec2_role_arn          (key policy principal)
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# INSTANCE PROFILE OUTPUTS
################################################################################

output "instance_profile_name" {
  description = "The name of the EC2 Instance Profile. Pass this to the Compute module Launch Template so every EC2 instance launched by the ASG automatically receives the IAM role and its permissions."
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "instance_profile_arn" {
  description = "The ARN of the EC2 Instance Profile. Use in CloudFormation cross-stack references or when creating resources that need to reference the profile by ARN."
  value       = aws_iam_instance_profile.ec2_profile.arn
}

################################################################################
# IAM ROLE OUTPUTS
################################################################################

output "ec2_role_name" {
  description = "The name of the EC2 IAM Role. Use when attaching additional inline policies or managed policies outside of this module."
  value       = aws_iam_role.ec2_role.name
}

output "ec2_role_arn" {
  description = "The ARN of the EC2 IAM Role. Add this as a Principal in S3 bucket policies, KMS key policies, and any resource-based policies that need to explicitly grant access to EC2 instances."
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_role_id" {
  description = "The unique ID of the EC2 IAM Role. Used in IAM policy conditions with aws:PrincipalArn to verify the exact role making an API call."
  value       = aws_iam_role.ec2_role.unique_id
}

################################################################################
# POLICY ARN OUTPUTS
################################################################################

output "s3_policy_arn" {
  description = "The ARN of the S3 access policy. Returns null if enable_s3_access is false. Reference this to attach the same policy to additional roles in other modules."
  value       = var.enable_s3_access ? aws_iam_policy.s3_access[0].arn : null
}

output "secrets_manager_policy_arn" {
  description = "The ARN of the Secrets Manager access policy. Returns null if enable_secrets_manager_access is false."
  value       = var.enable_secrets_manager_access ? aws_iam_policy.secrets_manager_access[0].arn : null
}

output "cloudwatch_policy_arn" {
  description = "The ARN of the CloudWatch access policy. Returns null if enable_cloudwatch_access is false."
  value       = var.enable_cloudwatch_access ? aws_iam_policy.cloudwatch_access[0].arn : null
}
