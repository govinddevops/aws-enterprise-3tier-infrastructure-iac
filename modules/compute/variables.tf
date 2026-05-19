################################################################################
# FILE         : modules/compute/variables.tf
# DESCRIPTION  : Input declarations for the Compute module.
#                Provisions EC2 Launch Template and Auto Scaling Group
#                across private subnets with ALB target group integration.
#
# INPUTS SOURCED FROM:
#   root variables   → instance_type, ami_id, key_pair_name, asg_*, root_volume_size
#   vpc module       → vpc_id, private_subnet_ids
#   sg module        → app_security_group_id
#   iam module       → instance_profile_name
#   alb module       → target_group_arn
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# SECTION 1: IDENTITY AND TAGGING
################################################################################

variable "name_prefix" {
  description = "Prefix for all compute resource names. Format: <project>-<environment>."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all compute resources via merge()."
  type        = map(string)
  default     = {}
}

variable "project_name" {
  description = "Project name passed into EC2 user data script for application configuration and CloudWatch log group naming."
  type        = string
}

variable "environment" {
  description = "Environment name passed into EC2 user data script. Application uses this to load the correct configuration profile."
  type        = string
}

################################################################################
# SECTION 2: NETWORK CONFIGURATION
################################################################################

variable "vpc_id" {
  description = "The VPC ID. Required for Auto Scaling Group and Launch Template VPC association."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs where EC2 instances will be launched. The ASG distributes instances across all listed subnets — one AZ per subnet — for high availability."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnet IDs required for multi-AZ EC2 deployment."
  }
}

################################################################################
# SECTION 3: SECURITY CONFIGURATION
################################################################################

variable "app_security_group_id" {
  description = "The Security Group ID to attach to EC2 instances. Must allow inbound port 80 from the ALB Security Group and inbound port 22 from VPC CIDR only."
  type        = string
}

################################################################################
# SECTION 4: IAM CONFIGURATION
################################################################################

variable "instance_profile_name" {
  description = "The name of the IAM Instance Profile to attach to EC2 instances. Provides temporary AWS credentials for S3, Secrets Manager, CloudWatch, and SSM access without hardcoded keys."
  type        = string
}

################################################################################
# SECTION 5: ALB INTEGRATION
################################################################################

variable "target_group_arn" {
  description = "The ARN of the ALB Target Group. The Auto Scaling Group registers new instances with this target group on launch and deregisters them on termination — automatically, with no manual intervention."
  type        = string
}

################################################################################
# SECTION 6: EC2 INSTANCE CONFIGURATION
################################################################################

variable "instance_type" {
  description = "EC2 instance type. t2.micro is Free Tier eligible. Defined in the Launch Template — changing this value creates a new Launch Template version without recreating the ASG."
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances. Leave empty to auto-resolve the latest Amazon Linux 2023 AMI via data source. Providing a specific AMI ID pins the deployment to that exact image version — recommended for production stability."
  type        = string
  default     = ""
}

variable "key_pair_name" {
  description = "Name of EC2 Key Pair for emergency SSH access. Must exist in AWS before terraform apply. With SSM Session Manager enabled, this key pair is a backup only — no port 22 needs to be open."
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB. Keep at 15 GiB with 2 instances to stay within 30 GiB Free Tier limit. gp3 volume type is used — cheaper and faster than gp2."
  type        = number
  default     = 15
}

################################################################################
# SECTION 7: AUTO SCALING CONFIGURATION
################################################################################

variable "asg_min_size" {
  description = "Minimum number of EC2 instances the ASG maintains at all times. The ASG will immediately launch replacement instances if the count drops below this number due to instance failure."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of EC2 instances the ASG can scale to. Hard ceiling on horizontal scaling — controls maximum cost exposure."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Target number of running EC2 instances under normal load. ASG continuously reconciles actual count to this number."
  type        = number
  default     = 2
}

variable "asg_health_check_grace_period" {
  description = "Seconds the ASG waits after an instance launches before checking its health. Must be long enough for the application to fully start. If health checks run too early, a slow-starting app causes unnecessary instance replacement."
  type        = number
  default     = 300
}

variable "scale_out_cpu_threshold" {
  description = "CPU utilisation percentage that triggers scale-out. When average CPU across all instances exceeds this for 2 consecutive periods, ASG adds an instance. Default 70% leaves headroom before saturation."
  type        = number
  default     = 70
}

variable "scale_in_cpu_threshold" {
  description = "CPU utilisation percentage that triggers scale-in. When average CPU drops below this for 5 consecutive periods, ASG removes an instance. Conservative threshold prevents thrashing."
  type        = number
  default     = 30
}
