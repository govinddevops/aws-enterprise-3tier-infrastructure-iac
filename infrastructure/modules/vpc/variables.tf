################################################################################
# FILE         : modules/vpc/variables.tf
# DESCRIPTION  : Input variable declarations for the VPC module.
#                All values are passed explicitly from root main.tf.
#                No variable reads root scope directly — modules are isolated.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# SECTION 1: IDENTITY AND TAGGING
################################################################################

variable "name_prefix" {
  description = "Prefix applied to all resource names created by this module. Format: <project>-<environment>. Example: enterprise-3tier-prod."
  type        = string
}

variable "common_tags" {
  description = "Map of common tags applied to every resource in this module via merge() with resource-specific tags. Sourced from root locals block."
  type        = map(string)
  default     = {}
}

################################################################################
# SECTION 2: VPC CONFIGURATION
################################################################################

variable "vpc_cidr" {
  description = "The primary IPv4 CIDR block for the VPC. All subnet CIDRs must be subsets of this block. Recommended: /16 for enterprise deployments."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, e.g. 10.0.0.0/16."
  }
}

################################################################################
# SECTION 3: SUBNET CONFIGURATION
################################################################################

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets. One per Availability Zone. Hosts ALB and NAT Gateways. Length must equal length of availability_zones."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnet CIDRs required for multi-AZ ALB deployment."
  }
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets. One per Availability Zone. Hosts EC2 application servers. No direct internet access — outbound via NAT Gateway only."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnet CIDRs required for multi-AZ EC2 deployment."
  }
}

variable "database_subnet_cidrs" {
  description = "List of CIDR blocks for database subnets. One per Availability Zone. Hosts RDS instances. Fully isolated — no internet route, no NAT Gateway access."
  type        = list(string)

  validation {
    condition     = length(var.database_subnet_cidrs) >= 2
    error_message = "At least 2 database subnet CIDRs required for RDS subnet group and Multi-AZ support."
  }
}

variable "availability_zones" {
  description = "List of Availability Zone names to deploy subnets into. Count must match the number of CIDRs in all three subnet lists. Example: [ap-south-1a, ap-south-1b]."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones required for high availability deployment."
  }
}

################################################################################
# SECTION 4: NAT GATEWAY CONFIGURATION
################################################################################

variable "enable_nat_gateway" {
  description = "Whether to provision NAT Gateway for private subnet outbound internet access. Required for EC2 instances to pull OS updates and reach AWS APIs. Costs approximately $32/month per gateway."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "When true, one NAT Gateway shared across all private subnets. Cost optimised but single point of failure. When false, one NAT Gateway per AZ for full HA. Set true for Free Tier."
  type        = bool
  default     = true
}
