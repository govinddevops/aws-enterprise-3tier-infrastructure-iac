################################################################################
# FILE         : variables.tf
# DESCRIPTION  : Root module input variable declarations with strict type
#                constraints, validation blocks, and enterprise descriptions.
#
# FIX APPLIED  : Removed illegal cross-variable reference in asg_max_size
#                validation block. Terraform validation blocks can only
#                reference their own variable — not other variables.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# SECTION 1: GLOBAL PROJECT IDENTIFIERS
################################################################################

variable "project_name" {
  description = "The name of the project. Used as a prefix in all resource names and as a default_tag on every AWS resource. Must be lowercase alphanumeric with hyphens only."
  type        = string
  default     = "enterprise-3tier"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens. No spaces or special characters allowed."
  }

  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 24
    error_message = "project_name must be between 3 and 24 characters."
  }
}

variable "environment" {
  description = "The deployment environment. Controls resource naming, instance sizing, and HA configurations. Allowed: dev, staging, prod."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "The team or individual responsible for this infrastructure. Applied as the Owner tag on every resource."
  type        = string
  default     = "devops-platform-team"
}

variable "cost_center" {
  description = "The finance cost-center code for billing attribution. Applied as the CostCenter tag on every resource."
  type        = string
  default     = "CC-INFRA-001"
}

################################################################################
# SECTION 2: AWS PROVIDER CONFIGURATION
################################################################################

variable "aws_region" {
  description = "The primary AWS region where all infrastructure will be provisioned."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "aws_region must be a valid AWS region format, e.g. ap-south-1, us-east-1."
  }
}

variable "aws_secondary_region" {
  description = "The secondary AWS region for disaster recovery provider alias. No resources are deployed here unless explicitly referenced."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_secondary_region))
    error_message = "aws_secondary_region must be a valid AWS region format, e.g. us-east-1."
  }
}

################################################################################
# SECTION 3: NETWORKING
################################################################################

variable "vpc_cidr" {
  description = "The primary IPv4 CIDR block for the VPC. A /16 block is recommended for enterprise deployments."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets. One per Availability Zone. Hosts ALB and NAT Gateways."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnet CIDRs are required for multi-AZ ALB deployment."
  }
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets. One per Availability Zone. Hosts EC2 application servers."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnet CIDRs are required for multi-AZ EC2 deployment."
  }
}

variable "database_subnet_cidrs" {
  description = "List of CIDR blocks for database subnets. One per Availability Zone. Fully isolated — no internet route."
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]

  validation {
    condition     = length(var.database_subnet_cidrs) >= 2
    error_message = "At least 2 database subnet CIDRs are required for RDS subnet group creation."
  }
}

variable "availability_zones" {
  description = "List of AWS Availability Zone names to deploy resources across. Must contain at least 2 AZs for high availability."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required for a highly available deployment."
  }
}

variable "enable_nat_gateway" {
  description = "Whether to provision a NAT Gateway for private subnet outbound internet access. Costs approximately $32/month. Set false for dev to save cost."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "When true, one shared NAT Gateway across all private subnets. Cost optimised but single point of failure. When false, one per AZ for full HA."
  type        = bool
  default     = true
}

################################################################################
# SECTION 4: COMPUTE
################################################################################

variable "instance_type" {
  description = "EC2 instance type for application servers. t2.micro is Free Tier eligible (750 hours/month for 12 months)."
  type        = string
  default     = "t2.micro"

  validation {
    condition = contains([
      "t2.micro", "t2.small", "t2.medium",
      "t3.micro", "t3.small", "t3.medium",
      "t3a.micro", "t3a.small"
    ], var.instance_type)
    error_message = "instance_type must be a valid Free Tier or small instance type."
  }
}

variable "ami_id" {
  description = "The AMI ID for EC2 instances. Leave empty to auto-resolve the latest Amazon Linux 2023 AMI via data source in the compute module."
  type        = string
  default     = ""
}

variable "key_pair_name" {
  description = "The name of an existing EC2 Key Pair for SSH access. Must exist in the target AWS region before terraform apply."
  type        = string
  default     = "enterprise-key"
}

variable "asg_min_size" {
  description = "Minimum number of EC2 instances the Auto Scaling Group maintains at all times. Ensures at least one instance is always running."
  type        = number
  default     = 1

  validation {
    condition     = var.asg_min_size >= 1 && var.asg_min_size <= 10
    error_message = "asg_min_size must be between 1 and 10."
  }
}

variable "asg_max_size" {
  description = "Maximum number of EC2 instances the ASG can scale to. Hard ceiling on horizontal scaling to control costs. Must be >= asg_min_size — enforced by AWS ASG API at apply time."
  type        = number
  default     = 2

  # FIX: Terraform validation blocks cannot reference other variables.
  # Cross-variable constraint (max >= min) is enforced by AWS ASG API.
  # We validate only the self-contained range here.
  validation {
    condition     = var.asg_max_size >= 1 && var.asg_max_size <= 10
    error_message = "asg_max_size must be between 1 and 10."
  }
}

variable "asg_desired_capacity" {
  description = "The desired number of EC2 instances the ASG maintains under normal operating conditions. Must be between asg_min_size and asg_max_size."
  type        = number
  default     = 2

  validation {
    condition     = var.asg_desired_capacity >= 1 && var.asg_desired_capacity <= 10
    error_message = "asg_desired_capacity must be between 1 and 10."
  }
}

variable "root_volume_size" {
  description = "Size in GiB for the EC2 root EBS volume. Keep at 15 GiB with 2 instances to stay within Free Tier 30 GiB total limit."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "root_volume_size must be between 8 and 100 GiB."
  }
}

variable "scale_out_cpu_threshold" {
  description = "CPU utilisation percentage that triggers scale-out. When average CPU exceeds this for 2 consecutive periods, ASG adds one instance."
  type        = number
  default     = 70

  validation {
    condition     = var.scale_out_cpu_threshold >= 10 && var.scale_out_cpu_threshold <= 100
    error_message = "scale_out_cpu_threshold must be between 10 and 100."
  }
}

variable "scale_in_cpu_threshold" {
  description = "CPU utilisation percentage that triggers scale-in. When average CPU drops below this for 5 consecutive periods, ASG removes one instance."
  type        = number
  default     = 30

  validation {
    condition     = var.scale_in_cpu_threshold >= 5 && var.scale_in_cpu_threshold <= 90
    error_message = "scale_in_cpu_threshold must be between 5 and 90."
  }
}

################################################################################
# SECTION 5: DATABASE
################################################################################

variable "db_engine" {
  description = "The database engine for the RDS instance. mysql and postgres are Free Tier eligible."
  type        = string
  default     = "mysql"

  validation {
    condition     = contains(["mysql", "postgres", "mariadb"], var.db_engine)
    error_message = "db_engine must be one of: mysql, postgres, mariadb."
  }
}

variable "db_engine_version" {
  description = "The version of the database engine. Must be compatible with db_instance_class."
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "The RDS instance class. db.t3.micro is Free Tier eligible — 750 hours/month for 12 months."
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = can(regex("^db\\.t[23]\\.(micro|small)$", var.db_instance_class))
    error_message = "db_instance_class must be db.t2.micro, db.t3.micro, or db.t3.small for Free Tier compliance."
  }
}

variable "db_name" {
  description = "The name of the initial database to create inside the RDS instance."
  type        = string
  default     = "enterprisedb"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "db_name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "db_username" {
  description = "The master username for the RDS instance. Cannot be a reserved word. Password is generated automatically inside the RDS module — never passed as a variable."
  type        = string
  default     = "dbadmin"

  validation {
    condition     = !contains(["admin", "root", "master", "superuser", "postgres"], var.db_username)
    error_message = "db_username cannot be a reserved word: admin, root, master, superuser, or postgres."
  }
}

variable "db_allocated_storage" {
  description = "The allocated storage size in GiB for the RDS instance. Free Tier provides 20 GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20 && var.db_allocated_storage <= 100
    error_message = "db_allocated_storage must be between 20 and 100 GiB."
  }
}

variable "db_max_allocated_storage" {
  description = "Maximum storage in GiB for RDS storage auto-scaling. Set to 0 to disable auto-scaling and prevent unexpected cost increases."
  type        = number
  default     = 0
}

variable "db_multi_az" {
  description = "Whether to enable Multi-AZ deployment for RDS. Provides automatic failover. NOT Free Tier eligible — doubles cost. Always false for Free Tier."
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated RDS backups. Range 0-35. Free Tier includes backup storage equal to DB size."
  type        = number
  default     = 7

  validation {
    condition     = var.db_backup_retention_period >= 0 && var.db_backup_retention_period <= 35
    error_message = "db_backup_retention_period must be between 0 and 35 days."
  }
}

variable "db_backup_window" {
  description = "Daily time window for automated RDS backups in UTC. Format: hh24:mi-hh24:mi. Must not overlap with db_maintenance_window."
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "Weekly time window for RDS maintenance in UTC. Format: ddd:hh24:mi-ddd:hh24:mi."
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "db_deletion_protection" {
  description = "Prevent RDS deletion via Terraform or AWS console. Must be set to false before destroying. Always true in real production."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on RDS deletion. Set false in production to preserve recovery point. Set true in dev for clean teardowns."
  type        = bool
  default     = true
}

variable "db_performance_insights_enabled" {
  description = "Enable RDS Performance Insights for query-level monitoring. Free for 7-day retention on Free Tier eligible instances."
  type        = bool
  default     = true
}

variable "db_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds. 0 disables enhanced monitoring. Valid values: 0, 1, 5, 10, 15, 30, 60."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.db_monitoring_interval)
    error_message = "db_monitoring_interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

################################################################################
# SECTION 6: LOAD BALANCER
################################################################################

variable "alb_deletion_protection" {
  description = "Whether to enable deletion protection on the Application Load Balancer. Always true in production environments."
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "The HTTP path the ALB target group health checker requests on each EC2 instance. Must return HTTP 200."
  type        = string
  default     = "/health"

  validation {
    condition     = can(regex("^/", var.health_check_path))
    error_message = "health_check_path must begin with a forward slash, e.g. /health."
  }
}

################################################################################
# SECTION 7: SECURITY
################################################################################

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks permitted to access the ALB on ports 80 and 443. Default is open to all internet traffic."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_allowed_cidr" {
  description = "CIDR block permitted to SSH into EC2 instances. Never use 0.0.0.0/0 in production. Restrict to VPC CIDR or corporate VPN range."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.ssh_allowed_cidr))
    error_message = "ssh_allowed_cidr must be a valid CIDR block, e.g. 10.0.0.0/16."
  }
}
