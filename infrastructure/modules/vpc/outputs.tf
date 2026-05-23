################################################################################
# FILE         : modules/vpc/outputs.tf
# DESCRIPTION  : Exports VPC resource identifiers for consumption by all
#                downstream modules: security_groups, alb, compute, rds.
#
# CONSUMED BY:
#   security_groups module → vpc_id, vpc_cidr_block
#   alb module             → vpc_id, public_subnet_ids
#   compute module         → vpc_id, private_subnet_ids
#   rds module             → db_subnet_group_name
#   root outputs.tf        → all outputs below
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# VPC OUTPUTS
################################################################################

output "vpc_id" {
  description = "The ID of the provisioned VPC. Required by all modules that create VPC-scoped resources such as security groups, subnets, and endpoints."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The primary CIDR block of the VPC. Used in security group ingress rules to allow unrestricted VPC-internal traffic between tiers."
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "The ARN of the VPC. Used in IAM resource policies and CloudTrail filtering."
  value       = aws_vpc.main.arn
}

################################################################################
# SUBNET OUTPUTS
################################################################################

output "public_subnet_ids" {
  description = "List of IDs of the public subnets across all configured AZs. Pass to the ALB module for internet-facing load balancer placement."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets across all configured AZs. Pass to the compute module for EC2 Auto Scaling Group placement."
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "List of IDs of the database subnets across all configured AZs. Fully isolated — no internet route."
  value       = aws_subnet.database[*].id
}

output "public_subnet_cidrs" {
  description = "List of CIDR blocks for the public subnets. Useful for security group rules that need to reference the public tier IP range."
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "List of CIDR blocks for the private subnets. Used in security group rules to allow VPC-internal traffic."
  value       = aws_subnet.private[*].cidr_block
}

output "database_subnet_cidrs" {
  description = "List of CIDR blocks for the database subnets."
  value       = aws_subnet.database[*].cidr_block
}

################################################################################
# GATEWAY OUTPUTS
################################################################################

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway. Confirms public internet connectivity is established for the VPC."
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs. Whitelist the corresponding Elastic IPs in external systems that allowlist your outbound traffic source."
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public Elastic IP addresses assigned to NAT Gateways. These are the source IPs for all outbound internet traffic from private subnets. Add to external API allowlists."
  value       = aws_eip.nat[*].public_ip
}

################################################################################
# ROUTE TABLE OUTPUTS
################################################################################

output "public_route_table_id" {
  description = "The ID of the public route table. Used when adding additional routes for VPC peering or Transit Gateway attachments."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of IDs of the private route tables. One per NAT Gateway. Used for VPC peering and Transit Gateway route propagation."
  value       = aws_route_table.private[*].id
}

output "database_route_table_id" {
  description = "The ID of the database route table. Fully isolated — no internet routes. Used for VPC endpoint route associations."
  value       = aws_route_table.database.id
}

################################################################################
# RDS SUBNET GROUP OUTPUT
################################################################################

output "db_subnet_group_name" {
  description = "The name of the RDS DB subnet group spanning all database subnets. Pass directly to the RDS module — required for RDS instance placement."
  value       = aws_db_subnet_group.main.name
}

output "db_subnet_group_arn" {
  description = "The ARN of the RDS DB subnet group."
  value       = aws_db_subnet_group.main.arn
}

################################################################################
# AVAILABILITY ZONE OUTPUTS
################################################################################

output "availability_zones_used" {
  description = "List of Availability Zone names where subnets were deployed. Confirms multi-AZ placement for high availability validation."
  value       = var.availability_zones
}
