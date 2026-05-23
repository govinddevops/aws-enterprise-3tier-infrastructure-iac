################################################################################
# FILE         : outputs.tf
# DESCRIPTION  : Root module outputs. Surfaces critical infrastructure
#                identifiers to the terminal post-apply and exposes values
#                for consumption by remote state data sources.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# SECTION 1: NETWORKING OUTPUTS
################################################################################

output "vpc_id" {
  description = "The ID of the provisioned VPC. Reference this in peering connections, Transit Gateway attachments, and security group rules in other projects."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The primary CIDR block of the VPC. Used in security group ingress rules to allow VPC-internal traffic."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs across all AZs. The ALB and NAT Gateways are deployed here."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs across all AZs. EC2 application servers are deployed here."
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "List of database subnet IDs across all AZs. RDS instances are deployed here."
  value       = module.vpc.database_subnet_ids
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs. Whitelist these Elastic IPs in external firewalls and third-party API allowlists."
  value       = module.vpc.nat_gateway_ids
}

################################################################################
# SECTION 2: SECURITY GROUP OUTPUTS
################################################################################

output "alb_security_group_id" {
  description = "Security Group ID attached to the ALB. Reference this in other modules to allow traffic from the ALB."
  value       = module.security_groups.alb_sg_id
}

output "app_security_group_id" {
  description = "Security Group ID attached to EC2 application servers."
  value       = module.security_groups.app_sg_id
}

output "database_security_group_id" {
  description = "Security Group ID attached to RDS instances."
  value       = module.security_groups.db_sg_id
}

################################################################################
# SECTION 3: LOAD BALANCER OUTPUTS
################################################################################

output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer. Point your Route 53 alias record or CNAME here. Paste this in a browser to access the application immediately after apply."
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer. Required for WAF association and CloudWatch alarm configuration."
  value       = module.alb.alb_arn
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the ALB. Required when creating Route 53 alias records for custom domain mapping."
  value       = module.alb.alb_zone_id
}

output "target_group_arn" {
  description = "The ARN of the ALB target group. EC2 instances register here to receive load-balanced traffic."
  value       = module.alb.target_group_arn
}

################################################################################
# SECTION 4: COMPUTE OUTPUTS
################################################################################

output "autoscaling_group_name" {
  description = "The name of the Auto Scaling Group managing EC2 application servers."
  value       = module.compute.autoscaling_group_name
}

output "autoscaling_group_arn" {
  description = "The ARN of the Auto Scaling Group. Required for scaling policies and CloudWatch alarm actions."
  value       = module.compute.autoscaling_group_arn
}

output "launch_template_id" {
  description = "The ID of the EC2 Launch Template. Defines the configuration applied to every instance the ASG launches."
  value       = module.compute.launch_template_id
}

output "launch_template_latest_version" {
  description = "The latest version number of the EC2 Launch Template. Increments every time the template is updated."
  value       = module.compute.launch_template_latest_version
}

################################################################################
# SECTION 5: DATABASE OUTPUTS
################################################################################

output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance. Format: hostname:port. Application servers use this to connect to the database. Never expose this publicly."
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "rds_port" {
  description = "The port on which the RDS instance accepts connections. MySQL default: 3306."
  value       = module.rds.db_instance_port
}

output "rds_instance_id" {
  description = "The RDS instance identifier. Use this to locate the instance in the AWS console and CLI operations."
  value       = module.rds.db_instance_id
}

output "db_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret storing the RDS master password. Application servers retrieve the password from here at runtime via IAM role permissions."
  value       = module.rds.db_secret_arn
  sensitive   = true
}

################################################################################
# SECTION 6: IAM OUTPUTS
################################################################################

output "ec2_instance_profile_name" {
  description = "The name of the IAM Instance Profile attached to EC2 instances. Grants permissions to access S3, Secrets Manager, and SSM without hardcoded credentials."
  value       = module.iam.instance_profile_name
}

output "ec2_iam_role_arn" {
  description = "The ARN of the IAM Role attached to EC2 instances. Reference this in S3 bucket policies and KMS key policies to grant access."
  value       = module.iam.ec2_role_arn
}

################################################################################
# SECTION 7: DEPLOYMENT SUMMARY
# A single structured output that gives a complete deployment overview.
# Useful for CI/CD pipelines that parse Terraform outputs as JSON:
#   terraform output -json deployment_summary
################################################################################

output "deployment_summary" {
  description = "Complete deployment summary. Run 'terraform output deployment_summary' for a structured overview of all critical endpoints and identifiers."
  value = {
    project         = var.project_name
    environment     = var.environment
    region          = var.aws_region
    application_url = "http://${module.alb.alb_dns_name}"
    vpc_id          = module.vpc.vpc_id
    asg_name        = module.compute.autoscaling_group_name
    rds_instance    = module.rds.db_instance_id
  }
}
