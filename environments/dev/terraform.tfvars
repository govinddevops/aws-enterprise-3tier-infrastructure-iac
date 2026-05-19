################################################################################
# FILE         : environments/dev/terraform.tfvars
# DESCRIPTION  : Development environment variable overrides.
#                Optimised for cost minimisation — not high availability.
#                Use with: terraform apply -var-file=environments/dev/terraform.tfvars
#
# COST PROFILE (approximate monthly):
#   EC2 t2.micro x1    : Free Tier (750 hrs/month)
#   RDS db.t3.micro x1 : Free Tier (750 hrs/month)
#   ALB                : ~$16/month (not Free Tier)
#   NAT Gateway        : $0 (disabled)
#   EBS 15 GiB x1      : Free Tier (30 GiB total)
#   Total estimate     : ~$16/month
#
# DIFFERENCES FROM PRODUCTION:
#   - Single EC2 instance (not 2) — no HA, cost optimised
#   - NAT Gateway disabled — dev instances cannot reach internet
#   - No deletion protection — fast teardowns for testing
#   - Skip final snapshot — clean destroy without backup cost
#   - Shorter backup retention — 1 day (not 7)
#   - No Multi-AZ RDS — single AZ, half the cost
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# GLOBAL
################################################################################

project_name = "enterprise-3tier"
environment  = "dev"
owner        = "devops-platform-team"
cost_center  = "CC-INFRA-DEV"

################################################################################
# PROVIDER
################################################################################

aws_region           = "ap-south-1"
aws_secondary_region = "us-east-1"

################################################################################
# NETWORKING
# NAT Gateway disabled in dev — saves ~$32/month.
# Dev EC2 instances use SSM Session Manager for shell access
# and S3 VPC Endpoint for S3 access — no internet needed.
################################################################################

vpc_cidr = "10.1.0.0/16"
# Different VPC CIDR from prod — allows VPC peering between dev and prod
# without CIDR overlap conflicts if ever needed.

public_subnet_cidrs = [
  "10.1.1.0/24",
  "10.1.2.0/24"
]

private_subnet_cidrs = [
  "10.1.10.0/24",
  "10.1.11.0/24"
]

database_subnet_cidrs = [
  "10.1.20.0/24",
  "10.1.21.0/24"
]

availability_zones = [
  "ap-south-1a",
  "ap-south-1b"
]

# Disabled — saves ~$32/month in dev
# Dev instances access AWS APIs via VPC Endpoints (free) not NAT Gateway
enable_nat_gateway = false
single_nat_gateway = true

################################################################################
# COMPUTE
# Single instance in dev — no HA required, minimises Free Tier usage.
# desired = min = 1 means ASG always runs exactly 1 instance.
################################################################################

instance_type        = "t2.micro"
ami_id               = ""
key_pair_name        = "enterprise-key"
root_volume_size     = 15

asg_min_size         = 1
asg_max_size         = 2
asg_desired_capacity = 1

# Lower CPU thresholds for dev — easier to trigger scaling for testing
scale_out_cpu_threshold = 60
scale_in_cpu_threshold  = 20

################################################################################
# DATABASE
# Single AZ, no Multi-AZ — halves RDS cost.
# Deletion protection OFF — allows clean 'terraform destroy' in dev.
# Skip final snapshot — no backup cost on teardown.
# Short backup retention — 1 day is sufficient for dev.
################################################################################

db_engine         = "mysql"
db_engine_version = "8.0"
db_instance_class = "db.t3.micro"
db_name           = "enterprisedb"
db_username       = "dbadmin"

db_allocated_storage    = 20
db_max_allocated_storage = 0

db_multi_az               = false
db_backup_retention_period = 1
db_backup_window          = "03:00-04:00"
db_maintenance_window     = "Mon:04:00-Mon:05:00"
db_deletion_protection    = false
db_skip_final_snapshot    = true

db_performance_insights_enabled = true
db_monitoring_interval          = 0

################################################################################
# LOAD BALANCER
################################################################################

alb_deletion_protection = false
health_check_path       = "/health"

################################################################################
# SECURITY
################################################################################

allowed_cidr_blocks = ["0.0.0.0/0"]
ssh_allowed_cidr    = "10.1.0.0/16"
