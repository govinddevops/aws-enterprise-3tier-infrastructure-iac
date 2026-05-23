################################################################################
# FILE         : modules/compute/outputs.tf
# DESCRIPTION  : Exports compute resource identifiers for the root module
#                outputs and external pipeline consumption.
#
# CONSUMED BY:
#   root outputs.tf  → autoscaling_group_name, launch_template_id
#   CI/CD pipelines  → autoscaling_group_name (for instance refresh commands)
#   CloudWatch       → autoscaling_group_name (metric dimension)
#   AWS Console      → all identifiers for manual verification
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# LAUNCH TEMPLATE OUTPUTS
################################################################################

output "launch_template_id" {
  description = "The ID of the EC2 Launch Template. Reference this in aws_autoscaling_group resources in other modules or stacks that share this application configuration."
  value       = aws_launch_template.app.id
}

output "launch_template_arn" {
  description = "The ARN of the EC2 Launch Template."
  value       = aws_launch_template.app.arn
}

output "launch_template_latest_version" {
  description = "The latest version number of the Launch Template. Increments every time a configuration change is applied. Use this to verify the ASG is running the expected template version."
  value       = aws_launch_template.app.latest_version
}

output "launch_template_name" {
  description = "The name of the EC2 Launch Template. Use with AWS CLI: aws ec2 describe-launch-template-versions --launch-template-name <value>"
  value       = aws_launch_template.app.name
}

################################################################################
# AUTO SCALING GROUP OUTPUTS
################################################################################

output "autoscaling_group_name" {
  description = "The name of the Auto Scaling Group. Use in CI/CD pipelines to trigger instance refresh: aws autoscaling start-instance-refresh --auto-scaling-group-name <value>"
  value       = aws_autoscaling_group.app.name
}

output "autoscaling_group_arn" {
  description = "The ARN of the Auto Scaling Group. Required for Auto Scaling lifecycle hook configurations and EventBridge rules targeting ASG events."
  value       = aws_autoscaling_group.app.arn
}

output "autoscaling_group_min_size" {
  description = "The configured minimum instance count of the ASG. Confirms Free Tier instance count boundary."
  value       = aws_autoscaling_group.app.min_size
}

output "autoscaling_group_max_size" {
  description = "The configured maximum instance count of the ASG. Confirms the horizontal scaling ceiling."
  value       = aws_autoscaling_group.app.max_size
}

output "autoscaling_group_desired_capacity" {
  description = "The current desired instance count of the ASG. May differ from configured value if scaling policies have adjusted it at runtime."
  value       = aws_autoscaling_group.app.desired_capacity
}

################################################################################
# SCALING POLICY OUTPUTS
################################################################################

output "scale_out_policy_arn" {
  description = "The ARN of the scale-out Auto Scaling policy. Reference this in external CloudWatch alarms or EventBridge rules that need to trigger additional scale-out events."
  value       = aws_autoscaling_policy.scale_out.arn
}

output "scale_in_policy_arn" {
  description = "The ARN of the scale-in Auto Scaling policy."
  value       = aws_autoscaling_policy.scale_in.arn
}

################################################################################
# CLOUDWATCH ALARM OUTPUTS
################################################################################

output "cpu_high_alarm_arn" {
  description = "The ARN of the high CPU CloudWatch alarm that triggers scale-out. Add additional alarm actions here to send SNS notifications during scale events."
  value       = aws_cloudwatch_metric_alarm.cpu_high.arn
}

output "cpu_low_alarm_arn" {
  description = "The ARN of the low CPU CloudWatch alarm that triggers scale-in."
  value       = aws_cloudwatch_metric_alarm.cpu_low.arn
}

################################################################################
# AMI INFORMATION OUTPUTS
################################################################################

output "ami_id_used" {
  description = "The actual AMI ID used by the Launch Template. If ami_id variable was empty, this shows the dynamically resolved Amazon Linux 2023 AMI ID. Pin this value in terraform.tfvars for production stability."
  value       = local.ami_id
}

output "ami_name" {
  description = "The name of the AMI used. Confirms which Amazon Linux 2023 release the instances are running. Reference this in security scan reports and compliance documentation."
  value       = data.aws_ami.amazon_linux_2023.name
}
