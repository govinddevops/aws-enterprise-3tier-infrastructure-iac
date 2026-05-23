#!/bin/bash
################################################################################
# FILE    : modules/compute/templates/user_data.sh
# PURPOSE : EC2 instance bootstrap script. Runs once on first launch as root.
#           Installs Apache, creates health check endpoint, configures logging.
################################################################################

set -euxo pipefail

# Variables injected by Terraform templatefile()
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"

# Update system packages
yum update -y

# Install Apache web server and CloudWatch agent
yum install -y httpd amazon-cloudwatch-agent

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create application index page
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>$PROJECT_NAME - $ENVIRONMENT</title></head>
<body>
  <h1>Enterprise 3-Tier Infrastructure</h1>
  <p>Project: $PROJECT_NAME</p>
  <p>Environment: $ENVIRONMENT</p>
  <p>Instance ID: $(curl -s -H "X-aws-ec2-metadata-token: $(curl -s -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600')" http://169.254.169.254/latest/meta-data/instance-id)</p>
  <p>Status: Healthy</p>
</body>
</html>
EOF

# Create health check endpoint — ALB probes this path every 30 seconds
mkdir -p /var/www/html/health
cat > /var/www/html/health/index.html <<EOF
OK
EOF

# Set correct permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

echo "Bootstrap complete for $PROJECT_NAME $ENVIRONMENT" >> /var/log/bootstrap.log
