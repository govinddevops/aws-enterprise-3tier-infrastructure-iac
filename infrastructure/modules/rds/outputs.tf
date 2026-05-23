################################################################################
# FILE         : modules/rds/outputs.tf
# DESCRIPTION  : Exports RDS instance identifiers and connection information
#                for root module outputs and application configuration.
#
# SECURITY NOTE:
#   db_instance_endpoint is marked sensitive — it reveals internal network
#   topology. The endpoint is passed to application configuration via
#   Secrets Manager or Parameter Store — never hardcoded in app config.
#
# CONSUMED BY:
#   root outputs.tf    → all outputs below for post-apply summary
#   application config → db_secret_arn (retrieve all connection details)
#   monitoring tools   → db_instance_id (CloudWatch dimension)
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# RDS INSTANCE OUTPUTS
################################################################################

output "db_instance_id" {
  description = "The RDS instance identifier. Use this to locate the instance in the AWS console, CLI operations, and CloudWatch metric dimensions."
  value       = aws_db_instance.main.identifier
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance. Reference in IAM policies, CloudWatch alarms targeting specific RDS instances, and AWS Backup plans."
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "The connection endpoint for the RDS instance in host:port format. Marked sensitive — do not log or expose in application output. Pass to application via Secrets Manager."
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "db_instance_address" {
  description = "The hostname portion of the RDS endpoint without the port. Use this when your application requires host and port as separate configuration values."
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "db_instance_port" {
  description = "The port on which the RDS instance accepts connections. MySQL default: 3306. Not sensitive — port numbers are not secret."
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "The name of the initial database created inside the RDS instance. This is the database name for application connection strings."
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "The master username for the RDS instance. Marked sensitive — treat master credentials with restricted access."
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_instance_class" {
  description = "The instance class of the RDS instance. Confirms Free Tier eligibility — should be db.t3.micro."
  value       = aws_db_instance.main.instance_class
}

output "db_instance_status" {
  description = "The current status of the RDS instance. Should be 'available' after successful apply. Useful for health verification in CI/CD pipelines."
  value       = aws_db_instance.main.status
}

output "db_engine_version_actual" {
  description = "The actual running engine version including minor version. May differ from the requested version if AWS applied a minor upgrade during provisioning."
  value       = aws_db_instance.main.engine_version_actual
}

################################################################################
# SECRETS MANAGER OUTPUTS
################################################################################

output "db_secret_arn" {
  description = "The ARN of the Secrets Manager secret storing RDS credentials. Provide this ARN to application developers — they use it in SDK calls to retrieve the full connection JSON including username, password, dbname, and engine."
  value       = aws_secretsmanager_secret.db_password.arn
  sensitive   = true
}

output "db_secret_name" {
  description = "The name of the Secrets Manager secret. Format: <project>/<environment>/rds/master-password. Use this name in aws CLI: aws secretsmanager get-secret-value --secret-id <value>"
  value       = aws_secretsmanager_secret.db_password.name
}

################################################################################
# PARAMETER GROUP OUTPUTS
################################################################################

output "db_parameter_group_name" {
  description = "The name of the custom RDS parameter group. Reference this when creating read replicas or restored instances that should inherit the same parameter configuration."
  value       = aws_db_parameter_group.main.name
}

output "db_parameter_group_arn" {
  description = "The ARN of the custom RDS parameter group."
  value       = aws_db_parameter_group.main.arn
}

################################################################################
# HIGH AVAILABILITY STATUS
################################################################################

output "db_multi_az" {
  description = "Whether Multi-AZ deployment is enabled. False confirms Free Tier single-AZ deployment. Set to true in production for automatic failover capability."
  value       = aws_db_instance.main.multi_az
}

output "db_availability_zone" {
  description = "The Availability Zone where the primary RDS instance is placed. Useful for verifying AZ placement in single-AZ deployments."
  value       = aws_db_instance.main.availability_zone
}
