################################################################################
# FILE         : modules/vpc/main.tf
# DESCRIPTION  : Provisions the complete 3-tier network foundation.
#
# RESOURCE CREATION ORDER:
#   1.  VPC
#   2.  Internet Gateway
#   3.  Public Subnets      (2x — one per AZ)
#   4.  Private Subnets     (2x — one per AZ)
#   5.  Database Subnets    (2x — one per AZ)
#   6.  Elastic IPs         (for NAT Gateways)
#   7.  NAT Gateways        (conditional — in public subnets)
#   8.  Public Route Table  + associations
#   9.  Private Route Table + associations
#   10. Database Route Table+ associations
#   11. RDS DB Subnet Group
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# RESOURCE 1: VPC
# The isolated network container. All resources in this project live inside.
# DNS support and DNS hostnames are enabled — required for RDS endpoint
# resolution and SSM Session Manager connectivity.
################################################################################

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Required for EC2 instances to resolve AWS service endpoints internally
  enable_dns_support = true

  # Required for EC2 instances to receive DNS hostnames like:
  # ip-10-0-10-5.ap-south-1.compute.internal
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

################################################################################
# RESOURCE 2: INTERNET GATEWAY
# Attaches to the VPC and provides the route to the public internet.
# Required for resources in public subnets to send and receive internet traffic.
# There is exactly one IGW per VPC — it is not AZ-specific.
################################################################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

################################################################################
# RESOURCE 3: PUBLIC SUBNETS
# count iterates over the public_subnet_cidrs list.
# One subnet is created per element — one per Availability Zone.
# map_public_ip_on_launch = true means EC2 instances launched here
# automatically receive a public IP (required for ALB nodes).
################################################################################

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-public-subnet-${count.index + 1}"
    Tier = "Public"
    AZ   = var.availability_zones[count.index]
    # Tag required by AWS Load Balancer Controller for Kubernetes ALB discovery
    "kubernetes.io/role/elb" = "1"
  })
}

################################################################################
# RESOURCE 4: PRIVATE SUBNETS
# Application tier subnets. EC2 instances live here.
# map_public_ip_on_launch = false — private instances never get public IPs.
# Outbound internet access only via NAT Gateway in the public subnet.
################################################################################

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-subnet-${count.index + 1}"
    Tier = "Private"
    AZ   = var.availability_zones[count.index]
    # Tag required by AWS Load Balancer Controller for internal ALB discovery
    "kubernetes.io/role/internal-elb" = "1"
  })
}

################################################################################
# RESOURCE 5: DATABASE SUBNETS
# Fully isolated — no route to internet, no NAT Gateway.
# Only the application tier security group can reach these subnets.
# RDS instances live here — they never need outbound internet access.
################################################################################

resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.database_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-database-subnet-${count.index + 1}"
    Tier = "Database"
    AZ   = var.availability_zones[count.index]
  })
}

################################################################################
# RESOURCE 6: ELASTIC IPs FOR NAT GATEWAYS
# Each NAT Gateway requires a static public IP (Elastic IP).
# count conditional: if enable_nat_gateway = false, count = 0 → no EIPs.
# If single_nat_gateway = true, count = 1 (one shared EIP).
# If single_nat_gateway = false, count = number of AZs (one EIP per AZ).
################################################################################

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  domain = "vpc"

  # EIP must be created after the Internet Gateway is attached
  depends_on = [aws_internet_gateway.main]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
  })
}

################################################################################
# RESOURCE 7: NAT GATEWAYS
# Lives in public subnets. Enables private subnet instances to initiate
# outbound connections to the internet (OS updates, AWS API calls)
# while blocking all inbound connections from the internet.
#
# count logic mirrors the EIP count:
#   enable = false → 0 NAT Gateways
#   enable = true, single = true  → 1 NAT Gateway in first public subnet
#   enable = true, single = false → 1 NAT Gateway per AZ in each public subnet
################################################################################

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  # Always place NAT Gateway in a public subnet
  subnet_id = aws_subnet.public[count.index].id

  # Reference corresponding EIP
  allocation_id = aws_eip.nat[count.index].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-nat-gw-${count.index + 1}"
  })
}

################################################################################
# RESOURCE 8: PUBLIC ROUTE TABLE
# One route table for all public subnets.
# Rule: all non-VPC traffic (0.0.0.0/0) goes to the Internet Gateway.
# VPC-local traffic (10.0.0.0/16) is handled automatically by AWS.
################################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-public-rt"
    Tier = "Public"
  })
}

################################################################################
# RESOURCE 9: PUBLIC ROUTE TABLE ASSOCIATIONS
# Associates each public subnet with the public route table.
# Without this association, subnets use the VPC default route table
# which has no internet route — a common misconfiguration.
################################################################################

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

################################################################################
# RESOURCE 10: PRIVATE ROUTE TABLES
# One route table per NAT Gateway.
# If single_nat_gateway = true  → 1 route table, all private subnets share it.
# If single_nat_gateway = false → 1 route table per AZ (true HA routing).
# Traffic to internet goes through NAT Gateway (not IGW directly).
################################################################################

resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 1

  vpc_id = aws_vpc.main.id

  # Only add NAT route if NAT Gateway is enabled
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-rt-${count.index + 1}"
    Tier = "Private"
  })
}

################################################################################
# RESOURCE 11: PRIVATE ROUTE TABLE ASSOCIATIONS
################################################################################

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

################################################################################
# RESOURCE 12: DATABASE ROUTE TABLE
# Fully isolated — no route to internet, no NAT Gateway route.
# Only VPC-local traffic is allowed (handled automatically by AWS).
# This is the most restrictive route table in the architecture.
################################################################################

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-database-rt"
    Tier = "Database"
  })
}

################################################################################
# RESOURCE 13: DATABASE ROUTE TABLE ASSOCIATIONS
################################################################################

resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

################################################################################
# RESOURCE 14: RDS DB SUBNET GROUP
# RDS requires a subnet group — a named collection of subnets across
# multiple AZs where it can place the primary and standby instances.
# Must span at least 2 AZs even for single-AZ deployments (AWS requirement).
# The subnet group references database subnets only — never public or private.
################################################################################

resource "aws_db_subnet_group" "main" {
  name        = "${var.name_prefix}-db-subnet-group"
  description = "RDS subnet group for ${var.name_prefix}. Spans database subnets in all configured AZs."
  subnet_ids  = aws_subnet.database[*].id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}
