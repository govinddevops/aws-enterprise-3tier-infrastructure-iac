################################################################################
# FILE         : environments/prod/terraform.tfvars
# DESCRIPTION  : Production environment — maximum reliability and security.
#                Every setting prioritises uptime and data protection over cost.
#
# USAGE:
#   terraform apply -var-file=environments/prod/terraform.tfvars
#   OR (uses this file automatically as the root default):
#   terraform apply
#
# COST PROFILE (approximate monthly):
#   EC2 t2.micro x2    : Free Tier (750 hrs/month — monitor closely)
#   RDS db.t3.micro x1 : Free Tier single-AZ (Multi-AZ doubles cost)
#   ALB                : ~$16/month
#   NAT Gateway x1     : ~$32/month (single shared for Free Tier)
#   EBS 15 GiB x2      : Free Tier (30 GiB total)
#   Total estimate     : ~$48/month
#
# PRODUCTION NON-NEGOTIABLES:
#   - deletion_protection = true on ALB and RDS
#   - skip_final_snapshot = false on RDS
#   - backup_retention_period = 7 days minimum
#   - storage_encrypted = true (enforced in module — not a variable)
#   - IMDSv2 required (enforced in Launch Template — not a variable)
#   - All traffic through ALB (enforced in Security Groups — not a variable)
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# GLOBAL
################################################################################

project_name = "enterprise-3tier"
environment  = "prod"
owner        = "devops-platform-team"
cost_center  = "CC-INFRA-001"

################################################################################
# PROVIDER
################################################################################

aws_region           = "ap-south-1"
aws_secondary_region = "us-east-1"

################################################################################
# NETWORKING
# Production uses 10.0.x.x — the primary CIDR block.
# Single NAT Gateway for Free Tier cost control.
# In a real production environment with HA requirements, set
# single_nat_gateway = false for one NAT Gateway per AZ (~$64/month).
################################################################################

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.10.0/24",
  "10.0.11.0/24"
]

database_subnet_cidrs = [
  "10.0.20.0/24",
  "10.0.21.0/24"
]

availability_zones = [
  "ap-south-1a",
  "ap-south-1b"
]

# Enabled — production EC2 instances require internet access for
# OS security patches, AWS API calls, and application dependencies
enable_nat_gateway = true

# true = cost optimised (Free Tier friendly)
# false = full HA (one NAT GW per AZ — recommended for real production)
single_nat_gateway = true

################################################################################
# COMPUTE
# 2 instances desired across 2 AZs — minimum HA configuration.
# If one AZ fails, the remaining instance serves all traffic while
# ASG launches a replacement in the healthy AZ automatically.
# Conservative CPU thresholds — scale out late, scale in very late.
################################################################################

instance_type    = "t2.micro"
ami_id           = ""
key_pair_name    = "enterprise-key"
root_volume_size = 15

asg_min_size         = 1
asg_max_size         = 2
asg_desired_capacity = 2

# High threshold — only scale out under sustained heavy load
# Prevents unnecessary scaling on brief traffic spikes
scale_out_cpu_threshold = 70

# Very conservative — only scale in when CPU is consistently very low
# Prevents removing capacity that may be needed within minutes
scale_in_cpu_threshold = 30

################################################################################
# DATABASE
# Production non-negotiables:
#   deletion_protection    = true  — cannot be deleted accidentally
#   skip_final_snapshot    = false — always take a snapshot before deletion
#   backup_retention       = 7     — 7 days of point-in-time recovery
#
# Multi-AZ note:
#   db_multi_az = false here for Free Tier compliance.
#   In a real production deployment, set to true for automatic failover.
#   Multi-AZ doubles RDS cost but provides < 60 second failover on AZ failure.
################################################################################

db_engine         = "mysql"
db_engine_version = "8.0"
db_instance_class = "db.t3.micro"
db_name           = "enterprisedb"
db_username       = "dbadmin"

db_allocated_storage     = 20
db_max_allocated_storage = 0

# Set true in real production — costs double but provides automatic failover
db_multi_az = false

db_backup_retention_period = 7
db_backup_window           = "02:00-03:00"
db_maintenance_window      = "Sun:03:00-Sun:04:00"

# PRODUCTION NON-NEGOTIABLE — must always be true in production
db_deletion_protection = true

# PRODUCTION NON-NEGOTIABLE — always preserve final snapshot before deletion
db_skip_final_snapshot = false

# Performance Insights free for 7-day retention — always enable in production
db_performance_insights_enabled = true

# Enhanced monitoring — set to 60 for production OS-level metrics
# Costs slightly more but provides CPU steal, memory, and disk I/O visibility
db_monitoring_interval = 0

################################################################################
# LOAD BALANCER
# PRODUCTION NON-NEGOTIABLE — deletion protection always on in production
# To delete the ALB: set false, apply, then destroy
################################################################################

alb_deletion_protection = true
health_check_path       = "/health"

################################################################################
# SECURITY
# In a real production deployment, replace 0.0.0.0/0 with your
# CloudFront managed prefix list ID to ensure all traffic passes
# through CloudFront WAF before reaching the ALB:
# allowed_cidr_blocks = [] — and use prefix_list_ids instead
################################################################################

allowed_cidr_blocks = ["0.0.0.0/0"]
ssh_allowed_cidr    = "10.0.0.0/16"
