################################################################################
# FILE         : modules/alb/variables.tf
# DESCRIPTION  : Input declarations for the Application Load Balancer module.
#
# INPUTS SOURCED FROM:
#   root variables   → name_prefix, common_tags, alb_deletion_protection,
#                      health_check_path
#   vpc module       → vpc_id, public_subnet_ids
#   sg module        → alb_security_group_id
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# SECTION 1: IDENTITY AND TAGGING
################################################################################

variable "name_prefix" {
  description = "Prefix for all ALB resource names. Format: <project>-<environment>."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all ALB resources via merge()."
  type        = map(string)
  default     = {}
}

################################################################################
# SECTION 2: NETWORK CONFIGURATION
# Sourced from VPC module outputs via root main.tf
################################################################################

variable "vpc_id" {
  description = "The VPC ID where the ALB target group will be created. Must match the VPC containing the EC2 instances that will receive traffic."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "vpc_id must be a valid AWS VPC ID, e.g. vpc-0a1b2c3d4e5f."
  }
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs across multiple AZs where the ALB will be deployed. An internet-facing ALB requires at least 2 subnets in different AZs — AWS enforces this as a hard requirement."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least 2 public subnet IDs are required for multi-AZ ALB deployment."
  }
}

################################################################################
# SECTION 3: SECURITY CONFIGURATION
# Sourced from security_groups module outputs via root main.tf
################################################################################

variable "alb_security_group_id" {
  description = "The ID of the Security Group to attach to the ALB. Must allow inbound HTTP port 80 and HTTPS port 443 from permitted CIDR blocks."
  type        = string

  validation {
    condition     = can(regex("^sg-[a-z0-9]+$", var.alb_security_group_id))
    error_message = "alb_security_group_id must be a valid Security Group ID, e.g. sg-0a1b2c3d4e5f."
  }
}

################################################################################
# SECTION 4: ALB BEHAVIOUR CONFIGURATION
################################################################################

variable "alb_deletion_protection" {
  description = "Enables deletion protection on the ALB. When true, the ALB cannot be deleted via Terraform or the AWS console without first disabling this setting. Always true in production."
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "The HTTP path the ALB target group health checker requests on each EC2 instance every 30 seconds. The application must return HTTP 200 on this path for the instance to receive traffic."
  type        = string
  default     = "/health"

  validation {
    condition     = can(regex("^/", var.health_check_path))
    error_message = "health_check_path must begin with a forward slash, e.g. /health."
  }
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks required before an instance transitions from unhealthy to healthy state and begins receiving traffic."
  type        = number
  default     = 2

  validation {
    condition     = var.health_check_healthy_threshold >= 2 && var.health_check_healthy_threshold <= 10
    error_message = "health_check_healthy_threshold must be between 2 and 10."
  }
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks required before an instance is marked unhealthy and removed from the target group rotation."
  type        = number
  default     = 3

  validation {
    condition     = var.health_check_unhealthy_threshold >= 2 && var.health_check_unhealthy_threshold <= 10
    error_message = "health_check_unhealthy_threshold must be between 2 and 10."
  }
}

variable "health_check_interval" {
  description = "Interval in seconds between ALB health check probes sent to each target instance. Lower values detect failures faster but increase health check traffic on your application."
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "health_check_interval must be between 5 and 300 seconds."
  }
}

variable "app_port" {
  description = "The port on which EC2 application instances listen for traffic from the ALB. Must match the port your application server binds to. Standard HTTP is 80."
  type        = number
  default     = 80

  validation {
    condition     = var.app_port > 0 && var.app_port <= 65535
    error_message = "app_port must be a valid port number between 1 and 65535."
  }
}
