################################################################################
# FILE         : modules/security_groups/variables.tf
# DESCRIPTION  : Input declarations for the Security Groups module.
#                Implements the 3-tier least-privilege firewall model:
#                ALB SG → App SG → DB SG
#                Each tier only accepts traffic from the tier above it.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# SECTION 1: IDENTITY AND TAGGING
################################################################################

variable "name_prefix" {
  description = "Prefix applied to all security group names and tags. Format: <project>-<environment>. Ensures consistent naming across all security groups in this module."
  type        = string
}

variable "common_tags" {
  description = "Map of common tags applied to every security group via merge() with resource-specific tags."
  type        = map(string)
  default     = {}
}

################################################################################
# SECTION 2: VPC CONTEXT
# Both values come from VPC module outputs passed through root main.tf.
################################################################################

variable "vpc_id" {
  description = "The ID of the VPC in which all security groups will be created. Security groups are VPC-scoped resources — they cannot be shared across VPCs."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID format, e.g. vpc-0a1b2c3d4e5f."
  }
}

variable "vpc_cidr" {
  description = "The CIDR block of the VPC. Used in security group rules to allow unrestricted intra-VPC communication where required — for example, allowing health check traffic."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

################################################################################
# SECTION 3: ACCESS CONTROL CONFIGURATION
################################################################################

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks permitted to reach the ALB on ports 80 and 443. Default is open to the internet. Restrict to corporate VPN CIDR for internal-only applications."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_cidr_blocks) > 0
    error_message = "allowed_cidr_blocks must contain at least one CIDR block."
  }
}

variable "ssh_allowed_cidr" {
  description = "CIDR block permitted to SSH into EC2 instances. Must never be 0.0.0.0/0 in production. Restrict to VPC CIDR for Bastion Host access or to your corporate VPN IP range."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.ssh_allowed_cidr))
    error_message = "ssh_allowed_cidr must be a valid IPv4 CIDR block."
  }
}

################################################################################
# SECTION 4: DATABASE PORT CONFIGURATION
################################################################################

variable "db_port" {
  description = "The port on which the RDS database accepts connections. MySQL default: 3306. PostgreSQL default: 5432. Must match the db_engine configured in the RDS module."
  type        = number
  default     = 3306

  validation {
    condition     = contains([3306, 5432, 1433, 1521], var.db_port)
    error_message = "db_port must be a valid database port: 3306 (MySQL), 5432 (PostgreSQL), 1433 (SQL Server), 1521 (Oracle)."
  }
}
