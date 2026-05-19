################################################################################
# FILE         : variables.tf
# DESCRIPTION  : Root module input variable declarations with strict type
#                constraints, validation blocks, and enterprise descriptions.
#
# ENTERPRISE STANDARD:
#   Every variable has:
#     1. A type constraint     — prevents wrong data types silently passing
#     2. A description         — serves as inline documentation for the team
#     3. A validation block    — catches invalid values before any API call
#     4. A sensible default    — where applicable, reduces required inputs
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# SECTION 1: GLOBAL PROJECT IDENTIFIERS
# These variables define the identity of this deployment. They are used in
# resource naming, tagging, and the S3 backend key path.
################################################################################

variable "project_name" {
  description = "The name of the project. Used as a prefix in all resource names and as a default_tag on every AWS resource. Must be lowercase alphanumeric with hyphens only — no spaces or special characters — to comply with AWS naming restrictions across all services."
  type        = string
  default     = "enterprise-3tier"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens. No spaces or special characters allowed."
  }

  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 24
    error_message = "project_name must be between 3 and 24 characters to stay within AWS resource naming limits."
  }
}

variable "environment" {
  description = "The deployment environment for this infrastructure. Controls resource naming conventions, instance sizing, and multi-AZ configurations. Accepted values: dev, staging, prod."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod. No other values are permitted."
  }
}

variable "owner" {
  description = "The team or individual responsible for this infrastructure. Applied as the Owner tag on every resource for incident escalation and cost accountability. Format: team-name or email."
  type        = string
  default     = "devops-platform-team"
}

variable "cost_center" {
  description = "The finance cost-center code for billing attribution. Applied as the CostCenter tag on every resource. Used by FinOps to split AWS bills across internal teams and products."
  type        = string
  default     = "CC-INFRA-001"
}

################################################################################
# SECTION 2: AWS PROVIDER CONFIGURATION
# Region targeting for primary deployment and disaster recovery.
################################################################################

variable "aws_region" {
  description = "The primary AWS region where all infrastructure will be provisioned. All resources except DR replicas will be created in this region."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "aws_region must be a valid AWS region format, e.g. ap-south-1, us-east-1, eu-west-1."
  }
}

variable "aws_secondary_region" {
  description = "The secondary AWS region for disaster recovery provider alias. No resources are actively deployed here unless a DR module explicitly references the secondary provider alias."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_secondary_region))
    error_message = "aws_secondary_region must be a valid AWS region format, e.g. us-east-1, eu-west-1."
  }
}

################################################################################
# SECTION 3: NETWORKING — VPC AND SUBNET CONFIGURATION
# CIDR block strategy follows RFC 1918 private address space.
# The /16 VPC provides 65,536 IPs — split across 6 subnets (/24 each = 256 IPs).
#
# SUBNET ARCHITECTURE:
#   Public  Subnets (2x) : ALB, NAT Gateway          — internet-facing
#   Private Subnets (2x) : EC2 application servers   — no direct internet
#   Database Subnets (2x): RDS instances              — fully isolated
################################################################################

variable "vpc_cidr" {
  description = "The primary IPv4 CIDR block for the VPC. Must be a valid RFC 1918 private address range. A /16 block is recommended for enterprise deployments to allow sufficient subnet carving across multiple tiers and AZs."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets. One per Availability Zone. These subnets host internet-facing resources: Application Load Balancer and NAT Gateways. Must be subsets of vpc_cidr."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnet CIDRs are required for multi-AZ ALB deployment."
  }
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets. One per Availability Zone. These subnets host EC2 application servers. Outbound internet access is via NAT Gateway. Must be subsets of vpc_cidr."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnet CIDRs are required for multi-AZ EC2 deployment."
  }
}

variable "database_subnet_cidrs" {
  description = "List of CIDR blocks for database subnets. One per Availability Zone. These subnets are fully isolated — no internet route, no NAT Gateway. Only the application tier can reach them. Must be subsets of vpc_cidr."
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]

  validation {
    condition     = length(var.database_subnet_cidrs) >= 2
    error_message = "At least 2 database subnet CIDRs are required for RDS Multi-AZ and subnet group creation."
  }
}

variable "availability_zones" {
  description = "List of AWS Availability Zone names to deploy resources across. Must contain at least 2 AZs for high availability. Count must match the number of CIDRs in public, private, and database subnet lists."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required for a highly available deployment."
  }
}

variable "enable_nat_gateway" {
  description = "Whether to provision a NAT Gateway for private subnet outbound internet access. Set to true for production (EC2 instances need to pull updates and reach AWS APIs). Set to false for dev to reduce cost — NAT Gateway costs approximately $32/month."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "When true, provisions a single NAT Gateway shared across all private subnets. Lower cost but single point of failure. When false, one NAT Gateway per AZ is provisioned for full HA. Set to true for Free Tier cost optimization."
  type        = bool
  default     = true
}

################################################################################
# SECTION 4: COMPUTE — EC2 AND AUTO SCALING CONFIGURATION
################################################################################

variable "instance_type" {
  description = "EC2 instance type for application servers. t2.micro is Free Tier eligible (750 hours/month for 12 months). Use t3.small or larger for actual production workloads."
  type        = string
  default     = "t2.micro"

  validation {
    condition = contains([
      "t2.micro", "t2.small", "t2.medium",
      "t3.micro", "t3.small", "t3.medium",
      "t3a.micro", "t3a.small"
    ], var.instance_type)
    error_message = "instance_type must be a valid Free Tier or small instance type. Large instance types are not permitted in this configuration."
  }
}

variable "ami_id" {
  description = "The Amazon Machine Image ID for EC2 instances. Must match the target aws_region. Leave empty to use the latest Amazon Linux 2023 AMI resolved dynamically via a data source in the compute module."
  type        = string
  default     = ""
}

variable "key_pair_name" {
  description = "The name of an existing EC2 Key Pair for SSH access to instances. The Key Pair must already exist in the target AWS region before terraform apply is run. Create one via: aws ec2 create-key-pair --key-name enterprise-key."
  type        = string
  default     = "enterprise-key"
}

variable "asg_min_size" {
  description = "Minimum number of EC2 instances the Auto Scaling Group will maintain at all times. Setting this to 1 ensures at least one instance is always running even during scale-in events."
  type        = number
  default     = 1

  validation {
    condition     = var.asg_min_size >= 1
    error_message = "asg_min_size must be at least 1 to ensure application availability."
  }
}

variable "asg_max_size" {
  description = "Maximum number of EC2 instances the Auto Scaling Group can scale out to. Caps the horizontal scaling ceiling to control costs. For Free Tier, keep this at 2."
  type        = number
  default     = 2

  validation {
    condition     = var.asg_max_size >= var.asg_min_size
    error_message = "asg_max_size must be greater than or equal to asg_min_size."
  }
}

variable "asg_desired_capacity" {
  description = "The desired number of EC2 instances the Auto Scaling Group will attempt to maintain under normal operating conditions. Must be between asg_min_size and asg_max_size."
  type        = number
  default     = 2
}

variable "root_volume_size" {
  description = "Size in GiB for the EC2 root EBS volume. Free Tier provides 30 GiB of EBS storage total. With 2 instances at 20 GiB each = 40 GiB which slightly exceeds Free Tier. Set to 15 to stay within limits."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "root_volume_size must be between 8 and 100 GiB."
  }
}

################################################################################
# SECTION 5: DATABASE — RDS CONFIGURATION
################################################################################

variable "db_engine" {
  description = "The database engine for the RDS instance. mysql is Free Tier eligible. postgres is also Free Tier eligible. aurora is NOT Free Tier eligible."
  type        = string
  default     = "mysql"

  validation {
    condition     = contains(["mysql", "postgres", "mariadb"], var.db_engine)
    error_message = "db_engine must be one of: mysql, postgres, mariadb. Aurora is not permitted in this Free Tier configuration."
  }
}

variable "db_engine_version" {
  description = "The version of the database engine. Must be compatible with the selected db_engine and the db_instance_class. Check AWS RDS documentation for valid version combinations."
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "The RDS instance class. db.t3.micro is Free Tier eligible (750 hours/month for 12 months). Do not use db.t3.small or larger in a Free Tier account."
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = can(regex("^db\\.t[23]\\.(micro|small)$", var.db_instance_class))
    error_message = "db_instance_class must be db.t2.micro, db.t3.micro, or db.t3.small for Free Tier compliance."
  }
}

variable "db_name" {
  description = "The name of the initial database to create inside the RDS instance. Must begin with a letter and contain only alphanumeric characters and underscores."
  type        = string
  default     = "enterprisedb"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "db_name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "db_username" {
  description = "The master username for the RDS instance. Cannot be 'admin', 'root', or other reserved words. The actual password is generated dynamically and stored in AWS Secrets Manager — never in this file."
  type        = string
  default     = "dbadmin"

  validation {
    condition     = !contains(["admin", "root", "master", "superuser", "postgres"], var.db_username)
    error_message = "db_username cannot be a reserved word: admin, root, master, superuser, or postgres."
  }
}

variable "db_allocated_storage" {
  description = "The allocated storage size in GiB for the RDS instance. Free Tier provides 20 GiB of General Purpose SSD storage. Do not exceed 20 GiB to stay within Free Tier limits."
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20 && var.db_allocated_storage <= 100
    error_message = "db_allocated_storage must be between 20 and 100 GiB. Minimum for MySQL is 20 GiB."
  }
}

variable "db_multi_az" {
  description = "Whether to enable Multi-AZ deployment for the RDS instance. Multi-AZ provides automatic failover to a standby replica in a different AZ. NOT Free Tier eligible — costs double. Set to false for Free Tier."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Whether to enable deletion protection on the RDS instance. When true, the database cannot be deleted via Terraform or the AWS console until this is set to false. Always true in production."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip the final snapshot when the RDS instance is destroyed. Set to false in production to preserve a final backup before deletion. Set to true in dev/staging to allow clean teardowns."
  type        = bool
  default     = true
}

################################################################################
# SECTION 6: LOAD BALANCER CONFIGURATION
################################################################################

variable "alb_deletion_protection" {
  description = "Whether to enable deletion protection on the Application Load Balancer. When enabled, the ALB cannot be deleted until this protection is removed. Always true in production environments."
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "The HTTP path the ALB target group health checker will request on each EC2 instance. The application must return HTTP 200 on this path for the instance to be considered healthy and receive traffic."
  type        = string
  default     = "/health"

  validation {
    condition     = can(regex("^/", var.health_check_path))
    error_message = "health_check_path must begin with a forward slash, e.g. /health or /api/status."
  }
}

################################################################################
# SECTION 7: SECURITY CONFIGURATION
################################################################################

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks permitted to access the Application Load Balancer on ports 80 and 443. Default is open to all internet traffic. Restrict this to specific IP ranges for internal or VPN-only deployments."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_allowed_cidr" {
  description = "CIDR block permitted to SSH into EC2 instances via the bastion host or direct access. Never use 0.0.0.0/0 in production. Restrict to your VPN CIDR or bastion host IP. Default is VPC-internal only."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.ssh_allowed_cidr))
    error_message = "ssh_allowed_cidr must be a valid CIDR block, e.g. 10.0.0.0/16 or 203.0.113.0/24."
  }
}
