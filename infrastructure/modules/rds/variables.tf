################################################################################
# FILE         : modules/rds/variables.tf
# DESCRIPTION  : Input declarations for the RDS database module.
#                Password management is intentionally absent — passwords
#                are generated internally and stored in Secrets Manager.
#                No password ever appears in variables, tfvars, or state
#                in plaintext.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# SECTION 1: IDENTITY AND TAGGING
################################################################################

variable "name_prefix" {
  description = "Prefix for all RDS resource names. Format: <project>-<environment>."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all RDS resources via merge()."
  type        = map(string)
  default     = {}
}

variable "project_name" {
  description = "Project name used to namespace the Secrets Manager secret storing the database password."
  type        = string
}

variable "environment" {
  description = "Environment name used in Secrets Manager secret path and RDS parameter group naming."
  type        = string
}

################################################################################
# SECTION 2: NETWORK CONFIGURATION
# Both values come from VPC and Security Groups module outputs.
################################################################################

variable "db_subnet_group_name" {
  description = "The name of the RDS DB subnet group spanning database subnets. Created by the VPC module and passed here. RDS instances are placed exclusively in database subnets — never public or private app subnets."
  type        = string
}

variable "db_security_group_id" {
  description = "The ID of the Database Security Group. Permits inbound database port only from the Application Security Group. Passed from the security_groups module output."
  type        = string
}

################################################################################
# SECTION 3: DATABASE ENGINE CONFIGURATION
################################################################################

variable "db_engine" {
  description = "The database engine. mysql and postgres are Free Tier eligible. mariadb is also supported."
  type        = string
  default     = "mysql"

  validation {
    condition     = contains(["mysql", "postgres", "mariadb"], var.db_engine)
    error_message = "db_engine must be one of: mysql, postgres, mariadb."
  }
}

variable "db_engine_version" {
  description = "The version of the database engine. Must be compatible with db_instance_class. Check AWS RDS documentation for valid combinations."
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "The RDS instance class. db.t3.micro is Free Tier eligible — 750 hours/month for 12 months. Never use db.r5 or db.m5 classes in a Free Tier account."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "The name of the initial database created inside the RDS instance. Application connection strings reference this name."
  type        = string
  default     = "enterprisedb"
}

variable "db_username" {
  description = "The master username for the RDS instance. Cannot be reserved words. Password is generated automatically inside this module — never passed as a variable."
  type        = string
  default     = "dbadmin"
}

variable "db_allocated_storage" {
  description = "Initial storage allocation in GiB. Free Tier provides 20 GiB. Storage auto-scaling is disabled to prevent unexpected cost increases."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum storage in GiB for RDS storage auto-scaling. Set to 0 to disable auto-scaling. Set equal to db_allocated_storage to disable. Prevents runaway storage costs."
  type        = number
  default     = 0
}

################################################################################
# SECTION 4: HIGH AVAILABILITY CONFIGURATION
################################################################################

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment. Creates a synchronous standby replica in a different AZ with automatic failover. NOT Free Tier eligible — doubles RDS cost. Always false for Free Tier."
  type        = bool
  default     = false
}

################################################################################
# SECTION 5: BACKUP AND RECOVERY CONFIGURATION
################################################################################

variable "db_backup_retention_period" {
  description = "Number of days to retain automated backups. Range 0-35. Set 0 to disable backups (not recommended even in dev). Free Tier includes backup storage equal to DB storage size."
  type        = number
  default     = 7

  validation {
    condition     = var.db_backup_retention_period >= 0 && var.db_backup_retention_period <= 35
    error_message = "db_backup_retention_period must be between 0 and 35 days."
  }
}

variable "db_backup_window" {
  description = "Daily time window for automated backups in UTC. Format: hh24:mi-hh24:mi. Must not overlap with db_maintenance_window. Choose a low-traffic period."
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "Weekly time window for RDS maintenance in UTC. Format: ddd:hh24:mi-ddd:hh24:mi. AWS may apply patches during this window — choose lowest traffic period."
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "db_deletion_protection" {
  description = "Prevent RDS deletion via Terraform or AWS console. When true, you must first set this to false and apply before destroying. Always true in production."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on deletion. Set false in production to preserve a recovery point. Set true in dev for clean teardowns."
  type        = bool
  default     = true
}

################################################################################
# SECTION 6: PERFORMANCE AND MONITORING
################################################################################

variable "db_performance_insights_enabled" {
  description = "Enable RDS Performance Insights for query-level monitoring. Free for 7-day retention on Free Tier eligible instances. Highly recommended — provides deep visibility into slow queries."
  type        = bool
  default     = true
}

variable "db_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds. 0 disables enhanced monitoring. Valid values: 0, 1, 5, 10, 15, 30, 60. Enhanced monitoring publishes OS-level metrics to CloudWatch."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.db_monitoring_interval)
    error_message = "db_monitoring_interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}
