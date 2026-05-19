################################################################################
# FILE         : terraform.tfvars
# DESCRIPTION  : Root module concrete variable values for production deployment.
#                This is the ONLY file that changes between environments.
#                Secrets are never stored here — use AWS Secrets Manager.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# SECTION 1: GLOBAL PROJECT IDENTIFIERS
################################################################################

project_name = "enterprise-3tier"
environment  = "prod"
owner        = "devops-platform-team"
cost_center  = "CC-INFRA-001"

################################################################################
# SECTION 2: AWS PROVIDER CONFIGURATION
################################################################################

# Primary region — Mumbai (closest for India-based deployments)
aws_region = "ap-south-1"

# Secondary region — DR provider alias (no resources deployed here yet)
aws_secondary_region = "us-east-1"

################################################################################
# SECTION 3: NETWORKING
#
# ARCHITECTURE:
#   VPC         : 10.0.0.0/16  — 65,536 IPs total
#   Public  /24 : ALB + NAT Gateway  (internet-facing)
#   Private /24 : EC2 app servers    (outbound via NAT only)
#   Database/24 : RDS instances      (fully isolated, no internet)
################################################################################

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = [
  "10.0.1.0/24",   # AZ: ap-south-1a — Public Tier
  "10.0.2.0/24"    # AZ: ap-south-1b — Public Tier
]

private_subnet_cidrs = [
  "10.0.10.0/24",  # AZ: ap-south-1a — Application Tier
  "10.0.11.0/24"   # AZ: ap-south-1b — Application Tier
]

database_subnet_cidrs = [
  "10.0.20.0/24",  # AZ: ap-south-1a — Database Tier
  "10.0.21.0/24"   # AZ: ap-south-1b — Database Tier
]

availability_zones = [
  "ap-south-1a",
  "ap-south-1b"
]

# WARNING: NAT Gateway costs ~$32/month
# Set true for production (EC2 needs outbound internet)
# Set false for dev/testing to save cost
enable_nat_gateway = true

# true  = one shared NAT Gateway (cost optimised, Free Tier friendly)
# false = one NAT Gateway per AZ (full HA, higher cost)
single_nat_gateway = true

################################################################################
# SECTION 4: COMPUTE
#
# FREE TIER LIMITS:
#   - t2.micro : 750 hours/month free for 12 months
#   - EBS      : 30 GiB total free — 2 instances x 15 GiB = 30 GiB exactly
################################################################################

instance_type = "t2.micro"

# Leave empty — compute module resolves latest Amazon Linux 2023 AMI
# automatically via data source. No manual AMI ID management needed.
ami_id = ""

# !! ACTION REQUIRED !!
# Replace with the name of an existing Key Pair in your AWS account.
# Create one with: aws ec2 create-key-pair --key-name enterprise-key \
#   --query 'KeyMaterial' --output text > ~/.ssh/enterprise-key.pem
key_pair_name = "enterprise-key"

# Auto Scaling Group sizing
# Free Tier: keep max at 2 to control costs
asg_min_size         = 1
asg_max_size         = 2
asg_desired_capacity = 2

# 15 GiB x 2 instances = 30 GiB total = exactly within Free Tier EBS limit
root_volume_size = 15

################################################################################
# SECTION 5: DATABASE
#
# FREE TIER LIMITS:
#   - db.t3.micro : 750 hours/month free for 12 months
#   - Storage     : 20 GiB General Purpose SSD free
#   - Multi-AZ    : NOT Free Tier — always false here
################################################################################

db_engine         = "mysql"
db_engine_version = "8.0"
db_instance_class = "db.t3.micro"
db_name           = "enterprisedb"
db_username       = "dbadmin"

# Storage — 20 GiB is the Free Tier maximum
db_allocated_storage = 20

# Multi-AZ doubles your RDS cost — disabled for Free Tier
db_multi_az = false

# Safety controls
# In real production: deletion_protection = true, skip_final_snapshot = false
db_deletion_protection  = false
db_skip_final_snapshot  = true

################################################################################
# SECTION 6: LOAD BALANCER
################################################################################

# Disabled so we can cleanly run 'terraform destroy' during testing
# Set to true in real production — prevents accidental ALB deletion
alb_deletion_protection = false

# Application must return HTTP 200 on this path for health checks to pass
health_check_path = "/health"

################################################################################
# SECTION 7: SECURITY
################################################################################

# ALB accepts traffic from the entire internet on ports 80 and 443
allowed_cidr_blocks = ["0.0.0.0/0"]

# SSH restricted to VPC-internal IPs only — never 0.0.0.0/0
# Only a Bastion Host or SSM Session Manager can reach EC2 via SSH
ssh_allowed_cidr = "10.0.0.0/16"
