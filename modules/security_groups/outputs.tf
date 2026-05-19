################################################################################
# FILE         : modules/security_groups/outputs.tf
# DESCRIPTION  : Exports Security Group IDs for attachment to downstream
#                resources in the ALB, Compute, and RDS modules.
#
# CONSUMED BY:
#   alb module     → alb_sg_id     (attached to Application Load Balancer)
#   compute module → app_sg_id     (attached to EC2 Launch Template)
#   rds module     → db_sg_id      (attached to RDS instance)
#   root outputs   → all three IDs for reference and documentation
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# ALB SECURITY GROUP OUTPUTS
################################################################################

output "alb_sg_id" {
  description = "The ID of the ALB Security Group. Attach this to the Application Load Balancer resource in the ALB module. Permits inbound HTTP and HTTPS from the internet."
  value       = aws_security_group.alb.id
}

output "alb_sg_arn" {
  description = "The ARN of the ALB Security Group. Use in IAM policies and CloudWatch metric filters that reference security groups by ARN."
  value       = aws_security_group.alb.arn
}

################################################################################
# APPLICATION SECURITY GROUP OUTPUTS
################################################################################

output "app_sg_id" {
  description = "The ID of the Application Security Group. Attach this to EC2 Launch Template in the Compute module. Permits inbound HTTP only from the ALB Security Group."
  value       = aws_security_group.app.id
}

output "app_sg_arn" {
  description = "The ARN of the Application Security Group."
  value       = aws_security_group.app.arn
}

################################################################################
# DATABASE SECURITY GROUP OUTPUTS
################################################################################

output "db_sg_id" {
  description = "The ID of the Database Security Group. Attach this to the RDS instance in the RDS module. Permits inbound database port only from the Application Security Group."
  value       = aws_security_group.db.id
}

output "db_sg_arn" {
  description = "The ARN of the Database Security Group."
  value       = aws_security_group.db.arn
}

################################################################################
# COMBINED OUTPUT FOR REFERENCE
################################################################################

output "security_group_summary" {
  description = "Map of all security group IDs for quick reference. Useful in CI/CD pipeline outputs and infrastructure documentation generation."
  value = {
    alb_sg_id = aws_security_group.alb.id
    app_sg_id = aws_security_group.app.id
    db_sg_id  = aws_security_group.db.id
  }
}
