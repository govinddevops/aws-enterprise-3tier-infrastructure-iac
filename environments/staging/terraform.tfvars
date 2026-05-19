################################################################################
# FILE         : environments/staging/terraform.tfvars
# DESCRIPTION  : Staging environment — production mirror with cost controls.
#                Close enough to production to catch real integration bugs.
#                Used for final QA, load testing, and release validation.
#
# USAGE:
#   terraform apply -var-file=environments/staging/terraform.tfvars
#
# COST PROFILE (approximate monthly):
#   EC2 t2.micro x2    : Free Tier (750 hrs/month — 2 instances = 1500 hrs)
#   RDS db.t3.micro x1 : Free Tier (750 hrs/month)
#   ALB                : ~$16/month
#   NAT Gateway x1     : ~$32/month (enabled — matches prod behaviour)
#   EBS 15 GiB x2      : Free Tier (30 GiB total)
#   Total estimate     : ~$48/month
#
# KEY DIFFERENCES FROM DEV:
#   - NAT Gateway enabled — matches production network behaviour
#   - 2 EC2 instances desired — tests multi-instance scenarios
#   - 7 day backup retention — matches production recovery requirements
#   - Deletion protection ON — prevents accidental staging teardown
#   - Skip final snapshot OFF — preserves DB state between test cycles
#
# KEY DIFFERENCES FROM PROD:
#   - Different VPC CIDR (10.2.x.x vs 10.0.x.x) — allows future peering
#   - No Multi-AZ RDS — cost control (staging tests app logic not DB HA)
#   - Lower scale-out threshold — easier to trigger for load testing
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# GLOBAL
################################################################################

project_name = "enterprise-3tier"
environment  = "staging"
owner        = "devops-platform-team"
cost_center  = "CC-INFRA-STG"

################################################################################
# PROVIDER
################################################################################

aws_region           = "ap-south-1"
aws_secondary_region = "us-east-1"

################################################################################
# NETWORKING
# NAT Gateway enabled — staging must replicate production network topology.
# Without NAT Gateway, EC2 instances cannot reach the internet for updates,
# and application behaviour may differ from production in subtle ways.
# single_nat_gateway = true keeps cost at ~$32/month vs ~$64/month for HA NAT.
################################################################################

vpc_cidr = "10.2.0.0/16"
# 10.2.x.x block — unique from dev (10.1.x.x) and prod (10.0.x.x)
# Enables future VPC peering between all three environments without CIDR conflicts

public_subnet_cidrs = [
  "10.2.1.0/24",
  "10.2.2.0/24"
]

private_subnet_cidrs = [
  "10.2.10.0/24",
  "10.2.11.0/24"
]

database_subnet_cidrs = [
  "10.2.20.0/24",
  "10.2.21.0/24"
]

availability_zones = [
  "ap-south-1a",
  "ap-south-1b"
]

# Enabled — matches production topology for accurate integration testing
enable_nat_gateway = true
single_nat_gateway = true

################################################################################
# COMPUTE
# 2 instances desired — validates multi-instance behaviour, session handling,
# and ALB distribution before these patterns reach production.
# Max 3 allows load testing to trigger one scale-out event.
################################################################################

instance_type        = "t2.micro"
ami_id               = ""
key_pair_name        = "enterprise-key"
root_volume_size     = 15

asg_min_size         = 1
asg_max_size         = 3
asg_desired_capacity = 2

# Lower threshold — makes it easier to trigger scaling during load tests
# without having to sustain 70% CPU for extended periods
scale_out_cpu_threshold = 60
scale_in_cpu_threshold  = 25

################################################################################
# DATABASE
# Single AZ to control cost — staging tests application logic, not DB HA.
# Deletion protection ON — staging DB contains test data worth preserving
# between release cycles. Prevents accidental teardown during CI/CD runs.
# Final snapshot enabled — provides recovery point if staging data is needed
# after an accidental destroy.
################################################################################

db_engine         = "mysql"
db_engine_version = "8.0"
db_instance_class = "db.t3.micro"
db_name           = "enterprisedb"
db_username       = "dbadmin"

db_allocated_storage     = 20
db_max_allocated_storage = 0

db_multi_az                = false
db_backup_retention_period = 7
db_backup_window           = "03:00-04:00"
db_maintenance_window      = "Mon:04:00-Mon:05:00"
db_deletion_protection     = true
db_skip_final_snapshot     = false

db_performance_insights_enabled = true
db_monitoring_interval          = 0

################################################################################
# LOAD BALANCER
# Deletion protection ON — prevents accidental ALB deletion during
# active staging test cycles. Must be manually disabled before teardown.
################################################################################

alb_deletion_protection = true
health_check_path       = "/health"

################################################################################
# SECURITY
# Restrict ALB access to corporate VPN CIDR in staging.
# Prevents external users from accessing staging environment URLs.
# Update 0.0.0.0/0 to your corporate VPN IP range for real isolation.
################################################################################

allowed_cidr_blocks = ["0.0.0.0/0"]
ssh_allowed_cidr    = "10.2.0.0/16"
