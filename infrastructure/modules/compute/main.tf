################################################################################
# FILE         : modules/compute/main.tf
# DESCRIPTION  : EC2 Launch Template, Auto Scaling Group, scaling policies,
#                and CloudWatch alarms for the application tier.
#
# RESOURCES CREATED:
#   1. data aws_ami              — Latest Amazon Linux 2023 AMI (dynamic)
#   2. aws_launch_template       — EC2 instance configuration blueprint
#   3. aws_autoscaling_group     — Manages EC2 fleet across AZs
#   4. aws_autoscaling_policy    — Scale-out on high CPU
#   5. aws_autoscaling_policy    — Scale-in on low CPU
#   6. aws_cloudwatch_metric_alarm — Triggers scale-out policy
#   7. aws_cloudwatch_metric_alarm — Triggers scale-in policy
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# DATA SOURCE: LATEST AMAZON LINUX 2023 AMI
#
# Dynamically resolves the most recent Amazon Linux 2023 AMI for the
# current region. This means:
#   - No hardcoded AMI IDs that become stale
#   - No manual AMI ID updates when AWS releases security patches
#   - Automatically picks the correct AMI for any region
#
# The filters narrow to:
#   - Amazon Linux 2023 (al2023) images only
#   - 64-bit x86 architecture (compatible with t2.micro, t3.micro)
#   - Only images in 'available' state
#   - Owned by Amazon (owner ID 137112412989) — prevents rogue AMIs
#
# If var.ami_id is provided, this data source is still fetched but unused.
# The local below selects the correct source.
################################################################################

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

################################################################################
# LOCAL: AMI SELECTION
# If var.ami_id is provided (non-empty), use it exactly.
# If var.ami_id is empty (default), use the dynamically resolved AMI.
# This pattern gives operators explicit control while defaulting to
# automatic resolution — best of both approaches.
################################################################################

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id

  # User data script — bootstraps the EC2 instance on first launch.
  # Installs and starts a web server, creates the health check endpoint,
  # and configures the CloudWatch agent for log shipping.
  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh", {
    project_name = var.project_name
    environment  = var.environment
  }))
}

################################################################################
# RESOURCE 1: EC2 LAUNCH TEMPLATE
#
# A Launch Template is the blueprint for every EC2 instance the ASG creates.
# It defines: AMI, instance type, storage, networking, security, and startup.
# Changes create new versions — the ASG can be updated to use the new version
# with zero downtime via instance refresh.
################################################################################

resource "aws_launch_template" "app" {
  name        = "${var.name_prefix}-app-lt"
  description = "Launch Template for ${var.name_prefix} application servers. Managed by Terraform — do not modify in AWS console."

  # AMI — dynamic resolution or explicit pin
  image_id = local.ami_id

  # Instance type — t2.micro for Free Tier
  instance_type = var.instance_type

  # Key pair for emergency SSH (SSM Session Manager is the primary access method)
  key_name = var.key_pair_name

  # Attach the application security group
  vpc_security_group_ids = [var.app_security_group_id]

  # Attach the IAM instance profile for AWS service access
  iam_instance_profile {
    name = var.instance_profile_name
  }

  ##############################################################################
  # EBS ROOT VOLUME CONFIGURATION
  # gp3 is the modern SSD type — 20% cheaper than gp2 and faster baseline.
  # Encryption at rest is enforced — mandatory for enterprise compliance.
  # delete_on_termination = true prevents orphaned volumes accumulating costs.
  ##############################################################################
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
      # throughput and iops at gp3 defaults (125 MB/s, 3000 IOPS)
      # sufficient for a typical web application workload
    }
  }

  ##############################################################################
  # INSTANCE METADATA SERVICE v2 (IMDSv2) — SECURITY HARDENING
  #
  # IMDSv1 is vulnerable to SSRF attacks:
  #   Attacker finds SSRF in app → requests http://169.254.169.254/
  #   → gets IAM credentials → full AWS access
  #
  # IMDSv2 requires a session token obtained via PUT request first.
  # SSRF attacks use GET requests — they cannot perform the PUT to
  # get a token — so they cannot access the metadata service.
  #
  # http_tokens = "required" — enforces IMDSv2, blocks IMDSv1 completely.
  # hop_limit = 1 — metadata token cannot be forwarded beyond 1 hop.
  #   Prevents containerised workloads from accessing host metadata.
  ##############################################################################
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  ##############################################################################
  # MONITORING
  # detailed_monitoring = true enables 1-minute CloudWatch metrics.
  # Default is 5-minute metrics (basic monitoring — free).
  # Detailed monitoring costs ~$2.10/instance/month — disabled for Free Tier.
  # Enable in production where fast anomaly detection justifies the cost.
  ##############################################################################
  monitoring {
    enabled = false
  }

  ##############################################################################
  # USER DATA
  # Base64-encoded shell script executed on first boot.
  # Installs web server, creates health check endpoint, configures logging.
  # templatefile() injects project_name and environment into the script.
  ##############################################################################
  user_data = local.user_data

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = "${var.name_prefix}-app-server"
      Role = "ApplicationServer"
      Tier = "Private"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.common_tags, {
      Name = "${var.name_prefix}-app-server-root-volume"
      Role = "RootVolume"
    })
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-app-lt"
  })

  # Always create new version before destroying old one
  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# RESOURCE 2: AUTO SCALING GROUP
#
# The ASG maintains the desired number of EC2 instances at all times.
# It spans multiple private subnets (= multiple AZs) for HA.
# New instances automatically register with the ALB target group.
# Failed instances are automatically detected and replaced.
################################################################################

resource "aws_autoscaling_group" "app" {
  name = "${var.name_prefix}-app-asg"

  # Distribute instances across all private subnets (multi-AZ)
  vpc_zone_identifier = var.private_subnet_ids

  # Instance count boundaries
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  # Grace period after instance launch before health checks begin.
  # Must be longer than application startup time.
  health_check_grace_period = var.asg_health_check_grace_period

  # ELB health check type uses ALB health checks to determine instance health.
  # More accurate than EC2 type which only checks if the instance is running —
  # ELB type checks if the APPLICATION is responding correctly.
  health_check_type = "ELB"

  # Automatically register/deregister instances with ALB target group
  target_group_arns = [var.target_group_arn]

  # Reference the Launch Template — always use latest version
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  ##############################################################################
  # INSTANCE REFRESH
  # When the Launch Template changes (new AMI, new instance type),
  # instance_refresh replaces instances gradually — not all at once.
  # min_healthy_percentage = 50 means at least 50% of instances remain
  # healthy during the refresh. For 2 instances: replaces 1 at a time.
  # This achieves zero-downtime deployments via ASG.
  ##############################################################################
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }

  ##############################################################################
  # TERMINATION POLICY
  # When scale-in occurs, which instance gets terminated first?
  # OldestLaunchTemplate: terminates instances using older LT versions first.
  # This naturally drains old-version instances during deployments.
  ##############################################################################
  termination_policies = ["OldestLaunchTemplate", "OldestInstance"]

  # Protect instances that are serving traffic from sudden termination.
  # The ALB deregistration delay (30s) handles in-flight request completion.
  wait_for_capacity_timeout = "10m"

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-app-asg"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    # Ignore desired_capacity changes made by scaling policies at runtime.
    # Without this, terraform plan always shows a diff when ASG has scaled.
    ignore_changes = [desired_capacity]
  }
}

################################################################################
# RESOURCE 3: SCALE-OUT POLICY
# Adds one instance when triggered by the high CPU CloudWatch alarm.
# cooldown = 300 seconds — wait 5 minutes after scaling before
# allowing another scale-out. Prevents rapid cascading scale events.
################################################################################

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.name_prefix}-scale-out-policy"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

################################################################################
# RESOURCE 4: SCALE-IN POLICY
# Removes one instance when triggered by the low CPU CloudWatch alarm.
# cooldown = 300 seconds — conservative to prevent premature scale-in.
################################################################################

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.name_prefix}-scale-in-policy"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

################################################################################
# RESOURCE 5: HIGH CPU ALARM — TRIGGERS SCALE-OUT
#
# Monitors average CPU across ALL instances in the ASG.
# When CPU > scale_out_cpu_threshold for 2 consecutive 60-second periods
# (= 2 minutes sustained high CPU), triggers the scale-out policy.
# evaluation_periods = 2 prevents scaling on momentary CPU spikes.
################################################################################

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.name_prefix}-cpu-high-alarm"
  alarm_description   = "Triggers scale-out when average ASG CPU exceeds ${var.scale_out_cpu_threshold}% for 2 consecutive minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_out_cpu_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  # When alarm fires → trigger scale-out policy
  alarm_actions = [aws_autoscaling_policy.scale_out.arn]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-cpu-high-alarm"
  })
}

################################################################################
# RESOURCE 6: LOW CPU ALARM — TRIGGERS SCALE-IN
#
# When CPU < scale_in_cpu_threshold for 5 consecutive 60-second periods
# (= 5 minutes sustained low CPU), triggers the scale-in policy.
# evaluation_periods = 5 is conservative — prevents removing instances
# during brief traffic lulls only to immediately need them again.
################################################################################

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.name_prefix}-cpu-low-alarm"
  alarm_description   = "Triggers scale-in when average ASG CPU drops below ${var.scale_in_cpu_threshold}% for 5 consecutive minutes."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_in_cpu_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  # When alarm fires → trigger scale-in policy
  alarm_actions = [aws_autoscaling_policy.scale_in.arn]

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-cpu-low-alarm"
  })
}
