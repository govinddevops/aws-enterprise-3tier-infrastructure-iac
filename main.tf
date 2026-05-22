################################################################################
# FILE         : main.tf
# DESCRIPTION  : Root module orchestrator. Calls all child modules in
#                dependency order. No AWS resources are created directly here.
#                This file IS the architecture — readable top to bottom.
#
# DEPENDENCY CHAIN:
#   vpc → security_groups → iam → alb → compute → rds
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# LOCALS
# Computed values derived from input variables. Centralises naming conventions
# so every module uses an identical, consistent resource naming pattern.
# Change the convention here once — it propagates everywhere automatically.
################################################################################

locals {

  # Master name prefix applied to every resource in every module.
  # Pattern: <project>-<environment>
  # Result : enterprise-3tier-prod
  name_prefix = "${var.project_name}-${var.environment}"

  # Common tags merged into every module call.
  # Modules combine these with resource-specific tags using merge().
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
    Repository  = "aws-enterprise-3tier-infrastructure-iac"
  }

}

################################################################################
# MODULE 1: VPC
# Provisions the entire network foundation first.
# Everything else depends on outputs from this module.
#
# CREATES:
#   - 1 VPC
#   - 2 Public Subnets  (ALB + NAT Gateway)
#   - 2 Private Subnets (EC2 application servers)
#   - 2 Database Subnets(RDS — fully isolated)
#   - Internet Gateway
#   - NAT Gateway (conditional)
#   - Public + Private Route Tables and Associations
#   - RDS DB Subnet Group
################################################################################

module "vpc" {
  source = "./modules/vpc"

  # Identity
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  # Network configuration — all driven from terraform.tfvars
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  availability_zones    = var.availability_zones

  # NAT Gateway controls
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
}

################################################################################
# MODULE 2: SECURITY GROUPS
# Provisions all Security Groups after VPC because SGs are VPC-scoped.
# Uses vpc_id output from the VPC module.
#
# CREATES:
#   - ALB Security Group  : inbound 80/443 from internet
#   - App Security Group  : inbound 80 from ALB SG only
#   - DB Security Group   : inbound 3306 from App SG only
#
# SECURITY MODEL:
#   Internet → ALB SG → App SG → DB SG
#   No direct internet access to EC2 or RDS. Ever.
################################################################################

module "security_groups" {
  source = "./modules/security_groups"

  # Identity
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  # VPC context — taken from VPC module output
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = var.vpc_cidr

  # Security configuration
  allowed_cidr_blocks = var.allowed_cidr_blocks
  ssh_allowed_cidr    = var.ssh_allowed_cidr
}

################################################################################
# MODULE 3: IAM
# Provisions IAM roles and instance profiles before compute.
# EC2 instances reference the instance profile at launch time.
#
# CREATES:
#   - EC2 IAM Role with trust policy (EC2 service can assume this role)
#   - IAM Policy: S3 read access (application config/assets)
#   - IAM Policy: Secrets Manager read (database password at runtime)
#   - IAM Policy: SSM Session Manager (SSH-free secure shell access)
#   - IAM Policy: CloudWatch Logs (application log shipping)
#   - Instance Profile (wrapper that attaches the role to EC2)
################################################################################

module "iam" {
  source = "./modules/iam"

  # Identity
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  # Project context
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

################################################################################
# MODULE 4: ALB
# Provisions the Application Load Balancer in public subnets.
# EC2 instances will register with this ALB's target group.
#
# CREATES:
#   - Application Load Balancer (internet-facing)
#   - ALB Target Group with health check configuration
#   - ALB Listener on port 80 (HTTP)
#   - ALB Listener Rule (forward all traffic to target group)
################################################################################

module "alb" {
  source = "./modules/alb"

  # Identity
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  # Network placement — public subnets from VPC module
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  # Security — ALB SG from security_groups module
  alb_security_group_id = module.security_groups.alb_sg_id

  # ALB configuration
  alb_deletion_protection = var.alb_deletion_protection
  health_check_path       = var.health_check_path
}

################################################################################
# MODULE 5: COMPUTE
# Provisions EC2 instances via Auto Scaling Group in private subnets.
# Depends on VPC (subnets), Security Groups (app SG), IAM (instance profile),
# and ALB (target group ARN for auto-registration).
#
# CREATES:
#   - EC2 Launch Template (AMI, instance type, user data, IMDSv2, EBS config)
#   - Auto Scaling Group spanning both private subnets
#   - ASG attachment to ALB Target Group
#   - Scale-out policy: CPU > 70% for 2 consecutive periods
#   - Scale-in policy : CPU < 30% for 5 consecutive periods
################################################################################

module "compute" {
  source = "./modules/compute"

  # Identity
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  # Network placement — private subnets from VPC module
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Security — app SG from security_groups module
  app_security_group_id = module.security_groups.app_sg_id

  # IAM — instance profile from iam module
  instance_profile_name = module.iam.instance_profile_name

  # ALB integration — registers instances with this target group
  target_group_arn = module.alb.target_group_arn

  # EC2 configuration
  instance_type    = var.instance_type
  ami_id           = var.ami_id
  key_pair_name    = var.key_pair_name
  root_volume_size = var.root_volume_size

  # Auto Scaling configuration
  asg_min_size         = var.asg_min_size
  asg_max_size         = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity

  # Runtime context passed into EC2 user data script
  project_name = var.project_name
  environment  = var.environment
}

################################################################################
# MODULE 6: RDS
# Provisions the database tier last — fully isolated in database subnets.
# Application servers connect to RDS using the endpoint output.
# Password is auto-generated and stored in Secrets Manager.
#
# CREATES:
#   - Random password (stored in Secrets Manager — never in state plaintext)
#   - AWS Secrets Manager Secret + Version (password storage)
#   - RDS DB Subnet Group (targets database subnets only)
#   - RDS Parameter Group (MySQL 8.0 tuning)
#   - RDS Instance (db.t3.micro — Free Tier eligible)
################################################################################

module "rds" {
  source = "./modules/rds"

  # Identity
  name_prefix = local.name_prefix
  common_tags = local.common_tags

  # Network placement — database subnets from VPC module
  db_subnet_group_name = module.vpc.db_subnet_group_name
  db_security_group_id = module.security_groups.db_sg_id

  # Database configuration
  db_engine              = var.db_engine
  db_engine_version      = var.db_engine_version
  db_instance_class      = var.db_instance_class
  db_name                = var.db_name
  db_username            = var.db_username
  db_allocated_storage   = var.db_allocated_storage
  db_multi_az            = var.db_multi_az
  db_deletion_protection = var.db_deletion_protection
  db_skip_final_snapshot = var.db_skip_final_snapshot

  # Context
  project_name = var.project_name
  environment  = var.environment
}
