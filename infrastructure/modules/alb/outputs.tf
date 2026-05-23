################################################################################
# FILE         : modules/alb/outputs.tf
# DESCRIPTION  : Exports ALB identifiers for consumption by the Compute
#                module and root outputs.
#
# CONSUMED BY:
#   compute module → target_group_arn (ASG registers instances here)
#   root outputs   → alb_dns_name     (application access URL)
#   root outputs   → alb_arn          (for WAF and CloudWatch alarms)
#   Route 53       → alb_zone_id      (alias record for custom domain)
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# APPLICATION LOAD BALANCER OUTPUTS
################################################################################

output "alb_id" {
  description = "The ID of the Application Load Balancer."
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer. Required for WAF web ACL association, Shield Advanced protection, and CloudWatch alarm configuration targeting this specific ALB."
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "The public DNS name of the ALB. Format: <name>-<id>.<region>.elb.amazonaws.com. Paste this in a browser immediately after terraform apply to access your application. Create a Route 53 CNAME or alias record pointing your custom domain to this value."
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the ALB. Use this — not a standard A record — when creating a Route 53 alias record for your custom domain. Alias records are free and resolve faster than CNAMEs."
  value       = aws_lb.main.zone_id
}

output "alb_arn_suffix" {
  description = "The ARN suffix of the ALB in the format app/<name>/<id>. Required specifically for CloudWatch metric dimensions when creating CPU and request count alarms on this ALB."
  value       = aws_lb.main.arn_suffix
}

################################################################################
# TARGET GROUP OUTPUTS
################################################################################

output "target_group_arn" {
  description = "The ARN of the ALB target group. Pass this to the Compute module so the Auto Scaling Group can automatically register new EC2 instances with this target group on launch."
  value       = aws_lb_target_group.app.arn
}

output "target_group_name" {
  description = "The name of the ALB target group. Used in CloudWatch metrics for HealthyHostCount and UnhealthyHostCount alarms."
  value       = aws_lb_target_group.app.name
}

output "target_group_arn_suffix" {
  description = "The ARN suffix of the target group. Required for CloudWatch metric dimensions alongside alb_arn_suffix when creating ALB request count and response time alarms."
  value       = aws_lb_target_group.app.arn_suffix
}

################################################################################
# LISTENER OUTPUTS
################################################################################

output "http_listener_arn" {
  description = "The ARN of the HTTP port 80 listener. Reference this when adding additional listener rules for path-based routing, e.g. /api/* → API target group, /* → web target group."
  value       = aws_lb_listener.http.arn
}

################################################################################
# CONVENIENCE OUTPUT
################################################################################

output "application_url" {
  description = "The full HTTP URL to access the application. Paste directly in a browser after terraform apply completes."
  value       = "http://${aws_lb.main.dns_name}"
}
