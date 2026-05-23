################################################################################
# FILE         : modules/security_groups/main.tf
# DESCRIPTION  : 3-tier least-privilege security group chain.
#
# FIREWALL CHAIN:
#   Internet → [ALB SG: 80,443] → [App SG: 80 from ALB SG only]
#                                → [DB SG: 3306 from App SG only]
#
# KEY PATTERN — SG-to-SG referencing:
#   Instead of allowing traffic from a CIDR block like "10.0.0.0/16",
#   we reference the SOURCE Security Group ID directly.
#   This means ONLY traffic that physically originated from a resource
#   carrying that specific SG is allowed. It cannot be spoofed.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# SECURITY GROUP 1: ALB SECURITY GROUP
# Attached to the Application Load Balancer.
# Accepts inbound HTTP and HTTPS from the internet.
# Allows all outbound so the ALB can forward requests to EC2 instances.
################################################################################

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Security Group for the Application Load Balancer. Permits inbound HTTP port 80 and HTTPS port 443 from the internet. All other inbound traffic is implicitly denied."
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-alb-sg"
    Role = "LoadBalancer"
  })

  # Lifecycle rule prevents security group destruction during updates.
  # create_before_destroy ensures the replacement SG exists before the
  # old one is deleted — preventing a window where ALB has no SG attached.
  lifecycle {
    create_before_destroy = true
  }
}

# INBOUND: HTTP from internet
resource "aws_security_group_rule" "alb_inbound_http" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id
  description       = "Allow inbound HTTP port 80 from permitted CIDR blocks. Traffic is forwarded to EC2 instances via the target group."

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = var.allowed_cidr_blocks
}

# INBOUND: HTTPS from internet
resource "aws_security_group_rule" "alb_inbound_https" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id
  description       = "Allow inbound HTTPS port 443 from permitted CIDR blocks. Requires SSL certificate configured on ALB listener."

  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = var.allowed_cidr_blocks
}

# OUTBOUND: All traffic to VPC
# ALB needs to forward requests to EC2 instances on port 80
# and perform health checks on the health_check_path endpoint.
resource "aws_security_group_rule" "alb_outbound_all" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic from ALB to VPC. Required for request forwarding to EC2 target group instances and health check probes."

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

################################################################################
# SECURITY GROUP 2: APPLICATION SECURITY GROUP
# Attached to EC2 instances in the private application tier.
#
# CRITICAL RULE:
#   Inbound port 80 is allowed ONLY from the ALB Security Group ID.
#   Not from a CIDR block. Not from the VPC range. From the ALB SG only.
#   This means traffic MUST pass through the ALB to reach EC2.
#   Direct access to EC2 from the internet or from other VPC resources
#   is impossible — even if someone knows the private IP.
################################################################################

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "Security Group for EC2 application servers. Accepts inbound HTTP only from the ALB Security Group. Blocks all direct internet access. SSH restricted to VPC CIDR only."
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-app-sg"
    Role = "ApplicationServer"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# INBOUND: HTTP from ALB SG only — THE KEY ENTERPRISE RULE
# source_security_group_id references the ALB SG directly.
# Only traffic from resources carrying the ALB SG passes this rule.
resource "aws_security_group_rule" "app_inbound_http_from_alb" {
  type              = "ingress"
  security_group_id = aws_security_group.app.id
  description       = "Allow inbound HTTP port 80 ONLY from the ALB Security Group. Enforces that all application traffic passes through the load balancer. Direct EC2 access from any other source is denied."

  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}

# INBOUND: SSH from VPC CIDR only
# Enables Bastion Host or SSM Session Manager access from within the VPC.
# Never 0.0.0.0/0 — that would expose SSH to the entire internet.
resource "aws_security_group_rule" "app_inbound_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.app.id
  description       = "Allow SSH port 22 from VPC CIDR only. Enables Bastion Host connectivity and AWS Systems Manager Session Manager access. Never permitted from 0.0.0.0/0."

  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [var.ssh_allowed_cidr]
}

# OUTBOUND: All traffic
# EC2 instances need outbound internet access for:
#   - OS security updates (yum update)
#   - AWS API calls (Secrets Manager, S3, CloudWatch)
#   - Application dependencies
resource "aws_security_group_rule" "app_outbound_all" {
  type              = "egress"
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound traffic from EC2 instances. Required for OS updates via NAT Gateway, AWS API calls, and application-level outbound connections."

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

################################################################################
# SECURITY GROUP 3: DATABASE SECURITY GROUP
# Attached to RDS instances in the isolated database tier.
#
# CRITICAL RULE:
#   Inbound database port is allowed ONLY from the App Security Group ID.
#   Not from the VPC CIDR. Not from the internet. From the App SG only.
#   Only EC2 instances carrying the App SG can reach the database.
#   If an attacker compromises the ALB, they still cannot reach RDS
#   because they do not carry the App SG — only EC2 instances do.
################################################################################

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "Security Group for RDS database instances. Accepts inbound database traffic only from the Application Security Group. No internet access. No SSH. Fully isolated."
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-sg"
    Role = "Database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# INBOUND: Database port from App SG only
# source_security_group_id = app SG ensures only EC2 instances
# in the application tier can establish database connections.
resource "aws_security_group_rule" "db_inbound_from_app" {
  type              = "ingress"
  security_group_id = aws_security_group.db.id
  description       = "Allow inbound database port from App Security Group only. Enforces that only application tier EC2 instances can establish database connections. All other sources are implicitly denied."

  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
}

# OUTBOUND: Restricted to VPC only
# RDS instances do not need internet access.
# Restricting outbound to VPC CIDR prevents any data exfiltration
# even if the database instance is somehow compromised.
resource "aws_security_group_rule" "db_outbound_vpc" {
  type              = "egress"
  security_group_id = aws_security_group.db.id
  description       = "Allow outbound traffic to VPC CIDR only. RDS does not require internet access. Restricting outbound to VPC prevents data exfiltration from the database tier."

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = [var.vpc_cidr]
}
