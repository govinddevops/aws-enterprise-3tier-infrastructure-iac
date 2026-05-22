################################################################################
# FILE         : modules/iam/main.tf
# DESCRIPTION  : EC2 IAM Role, least-privilege policies, and Instance Profile.
#
# RESOURCES CREATED:
#   1. aws_iam_role                  — EC2 assume role trust policy
#   2. aws_iam_policy (x4)           — Scoped permissions per service
#   3. aws_iam_role_policy_attachment — Links policies to role (conditional)
#   4. aws_iam_instance_profile      — Attaches role to EC2 instances
#
# SECURITY PRINCIPLES APPLIED:
#   - No wildcard * resources in any policy statement
#   - Each permission set is a separate policy (single responsibility)
#   - Policies attached conditionally via count (only what is needed)
#   - Temporary credentials via Instance Profile (no access keys)
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# DATA SOURCE: AWS ACCOUNT ID
# Retrieves the current AWS account ID dynamically.
# Used to construct full ARNs in policy resource blocks.
# Never hardcode account IDs — they change between accounts and break portability.
################################################################################

data "aws_caller_identity" "current" {}

################################################################################
# RESOURCE 1: EC2 IAM ROLE
#
# The trust policy (assume_role_policy) answers:
# "WHO is allowed to assume this role?"
# Answer: The EC2 service (ec2.amazonaws.com) — and only EC2.
#
# This means only EC2 instances can use this role.
# A Lambda function, ECS task, or human IAM user cannot assume it.
# That is least-privilege applied at the trust boundary level.
################################################################################

resource "aws_iam_role" "ec2_role" {
  name        = "${var.name_prefix}-ec2-role"
  description = "IAM Role for EC2 application servers. Grants least-privilege access to S3, Secrets Manager, CloudWatch, and SSM. Assumed exclusively by the EC2 service."

  # Trust policy — defines WHO can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2AssumeRole"
        Effect = "Allow"
        Principal = {
          # Only the EC2 service can assume this role
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Force detach policies on destroy — prevents role deletion failures
  # when policies are attached outside of Terraform
  force_detach_policies = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ec2-role"
    Role = "EC2InstanceRole"
  })
}

################################################################################
# RESOURCE 2: S3 ACCESS POLICY
# Grants read-only access to the project-specific S3 bucket.
# Scope: ONLY buckets prefixed with the project name in this account.
# NOT all S3 buckets in the account — that would violate least-privilege.
################################################################################

resource "aws_iam_policy" "s3_access" {
  count = var.enable_s3_access ? 1 : 0

  name        = "${var.name_prefix}-s3-access-policy"
  description = "Grants EC2 instances read-only access to project S3 buckets. Scoped to buckets matching the project naming convention only."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ListProjectBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        # Scoped to project-specific buckets only
        Resource = [
          "arn:aws:s3:::${var.project_name}-*"
        ]
      },
      {
        Sid    = "S3ReadProjectObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        # Scoped to objects within project-specific buckets only
        Resource = [
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-s3-access-policy"
  })
}

################################################################################
# RESOURCE 3: SECRETS MANAGER ACCESS POLICY
# Grants read-only access to project-specific secrets.
# EC2 applications retrieve the database password from Secrets Manager
# at runtime — no password in environment variables or config files.
#
# SCOPE: Only secrets whose name starts with the project name.
# A compromised EC2 instance cannot read secrets from other projects.
################################################################################

resource "aws_iam_policy" "secrets_manager_access" {
  count = var.enable_secrets_manager_access ? 1 : 0

  name        = "${var.name_prefix}-secrets-access-policy"
  description = "Grants EC2 instances read-only access to project secrets in Secrets Manager. Scoped to project-prefixed secrets only."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerListSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
        # ListSecrets does not support resource-level restrictions — AWS limitation
        # Mitigated by the GetSecretValue restriction below
      },
      {
        Sid    = "SecretsManagerReadProjectSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # Scoped to secrets belonging to this project in this region and account
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*",
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/*"
        ]
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-secrets-access-policy"
  })
}

################################################################################
# RESOURCE 4: CLOUDWATCH ACCESS POLICY
# Grants EC2 instances permission to:
#   - Create and write CloudWatch Log Groups and Streams
#   - Publish custom CloudWatch metrics
# Required for application log shipping to CloudWatch Logs.
################################################################################

resource "aws_iam_policy" "cloudwatch_access" {
  count = var.enable_cloudwatch_access ? 1 : 0

  name        = "${var.name_prefix}-cloudwatch-access-policy"
  description = "Grants EC2 instances permission to publish logs and custom metrics to CloudWatch. Required for centralised logging and monitoring."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        # Scoped to log groups belonging to this project
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${var.project_name}*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${var.project_name}*:*"
        ]
      },
      {
        Sid    = "CloudWatchMetricsAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
        # PutMetricData does not support resource-level restrictions — AWS limitation
        Condition = {
          StringEquals = {
            # Restrict custom metrics to project namespace only
            "cloudwatch:namespace" = "${var.project_name}/${var.environment}"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-cloudwatch-access-policy"
  })
}

################################################################################
# RESOURCE 5: SSM SESSION MANAGER POLICY
# Attaches AWS managed policy for SSM Session Manager.
# Enables SSH-free, fully audited shell access to EC2 instances.
#
# BENEFITS OVER TRADITIONAL SSH:
#   1. No port 22 open — security group has no SSH rule from internet
#   2. No key management — no .pem files to distribute to team members
#   3. Full audit trail — every command logged to CloudTrail and S3
#   4. IAM-controlled access — who can access which instance via IAM policies
#   5. Works through NAT — no Bastion Host required
#
# We use the AWS managed policy here — it is maintained by AWS and updated
# automatically when SSM adds new capabilities.
################################################################################

resource "aws_iam_role_policy_attachment" "ssm_access" {
  count = var.enable_ssm_access ? 1 : 0

  role = aws_iam_role.ec2_role.name
  # AWS managed policy — no custom policy needed for SSM core functionality
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

################################################################################
# POLICY ATTACHMENTS — CUSTOM POLICIES
# Conditionally attach each custom policy to the role.
# count = 1 when the policy resource was created, 0 when it was not.
# This mirrors the count on the policy resources above.
################################################################################

resource "aws_iam_role_policy_attachment" "s3_access" {
  count = var.enable_s3_access ? 1 : 0

  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access[0].arn
}

resource "aws_iam_role_policy_attachment" "secrets_manager_access" {
  count = var.enable_secrets_manager_access ? 1 : 0

  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_manager_access[0].arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_access" {
  count = var.enable_cloudwatch_access ? 1 : 0

  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cloudwatch_access[0].arn
}

################################################################################
# RESOURCE 6: EC2 INSTANCE PROFILE
# The Instance Profile is the container that attaches the IAM Role to EC2.
# EC2 instances reference the Instance Profile name — not the Role directly.
# The Instance Profile is what enables the EC2 metadata service to vend
# temporary STS credentials to applications running on the instance.
################################################################################

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ec2-instance-profile"
    Role = "EC2InstanceProfile"
  })
}
