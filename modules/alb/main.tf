################################################################################
# FILE         : modules/alb/main.tf
# DESCRIPTION  : Provisions the Application Load Balancer stack.
#
# RESOURCES CREATED:
#   1. aws_lb                — Internet-facing ALB in public subnets
#   2. aws_lb_target_group   — Pool of EC2 instances receiving traffic
#   3. aws_lb_listener       — Port 80 rule forwarding to target group
#
# TRAFFIC FLOW:
#   Browser → ALB DNS → Listener (port 80) → Target Group → EC2 (port 80)
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

################################################################################
# RESOURCE 1: APPLICATION LOAD BALANCER
#
# internal = false → internet-facing, has a public DNS name
# load_balancer_type = "application" → Layer 7, HTTP/HTTPS aware
#
# The ALB is placed in public subnets across all configured AZs.
# It receives internet traffic and distributes it to private EC2 instances.
# EC2 instances are never directly reachable from the internet.
################################################################################

resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"

  # Attach the ALB Security Group — allows inbound 80/443 from internet
  security_groups = [var.alb_security_group_id]

  # Span all public subnets — one per AZ for cross-zone load balancing
  subnets = var.public_subnet_ids

  # Prevents accidental deletion in production
  # Controlled by alb_deletion_protection variable
  enable_deletion_protection = var.alb_deletion_protection

  # Cross-zone load balancing is enabled by default on ALBs.
  # It distributes traffic evenly across all registered targets
  # regardless of which AZ the request arrived in.
  # No additional cost for ALBs (unlike NLBs where it has a charge).
  enable_cross_zone_load_balancing = true

  # HTTP/2 improves performance for browsers that support it.
  # Falls back to HTTP/1.1 for older clients automatically.
  enable_http2 = true

  # Idle timeout: how long ALB keeps a connection open with no data.
  # 60 seconds is the AWS default — sufficient for most applications.
  # Increase for long-polling or WebSocket applications.
  idle_timeout = 60

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-alb"
    Role = "ApplicationLoadBalancer"
    Tier = "Public"
  })
}

################################################################################
# RESOURCE 2: ALB TARGET GROUP
#
# A Target Group is the pool of EC2 instances that receive traffic.
# The ALB does not know about individual EC2 instances directly —
# it only knows about Target Groups. Instances register themselves
# with the Target Group when they are launched by the Auto Scaling Group.
#
# Health checks run on every registered instance every 'interval' seconds.
# Unhealthy instances are removed from rotation automatically.
# Recovered instances are re-added automatically after passing health checks.
################################################################################

resource "aws_lb_target_group" "app" {
  name     = "${var.name_prefix}-app-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # target_type = "instance" means we register EC2 instance IDs.
  # Alternative: "ip" for containers, "lambda" for serverless.
  target_type = "instance"

  ##############################################################################
  # HEALTH CHECK CONFIGURATION
  #
  # The ALB sends GET requests to health_check_path on each instance.
  # HTTP 200-299 response = healthy → instance receives traffic.
  # No response or non-2xx = unhealthy → instance removed from rotation.
  #
  # PRODUCTION TUNING:
  #   healthy_threshold   = 2  → 2 consecutive passes to become healthy
  #   unhealthy_threshold = 3  → 3 consecutive failures to become unhealthy
  #   interval            = 30 → check every 30 seconds
  #   timeout             = 5  → wait 5 seconds for response
  #   This means an instance failure is detected in ~90 seconds (3 x 30).
  ##############################################################################
  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    interval            = var.health_check_interval
    timeout             = 5
    matcher             = "200-299"
  }

  ##############################################################################
  # STICKINESS (SESSION AFFINITY)
  # Disabled — stateless application tier is the enterprise standard.
  # Session state is stored externally (ElastiCache/Redis or DynamoDB).
  # Sticky sessions create uneven load distribution and complicate scaling.
  # If your application requires stickiness, store session in Redis instead.
  ##############################################################################
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }

  ##############################################################################
  # DEREGISTRATION DELAY
  # When an instance is removed from the target group (scale-in or deployment),
  # the ALB waits this many seconds before fully deregistering it.
  # During this window, in-flight requests complete gracefully.
  # 30 seconds is sufficient for most applications.
  # The default is 300 seconds — reduced here for faster deployments.
  ##############################################################################
  deregistration_delay = 30

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-app-tg"
    Role = "TargetGroup"
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# RESOURCE 3: ALB HTTP LISTENER
#
# A Listener defines the rule: "when traffic arrives on this port,
# do this action". Here: port 80 → forward to the app target group.
#
# PRODUCTION UPGRADE PATH:
#   In production with HTTPS, you would add a second listener on port 443
#   with an ACM SSL certificate, and change this port 80 listener to
#   redirect all HTTP traffic to HTTPS:
#
#   default_action {
#     type = "redirect"
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
################################################################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-http-listener"
    Role = "ALBListener"
    Port = "80"
  })
}
