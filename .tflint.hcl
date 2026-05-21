########################################################################
# FILE         : .tflint.hcl
# DESCRIPTION  : TFLint enterprise configuration with AWS ruleset.
#                Enforces AWS best practices and catches common errors
#                that terraform validate cannot detect.
########################################################################

plugin "aws" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  # Enables module inspection
  module = true

  # Forces TFLint to fail on any rule violation
  force = false
}

# Disallow deprecated instance types
rule "aws_instance_invalid_type" {
  enabled = true
}

# Enforce naming conventions
rule "terraform_naming_convention" {
  enabled = true
}

# Require all variables to have descriptions
rule "terraform_documented_variables" {
  enabled = true
}

# Require all outputs to have descriptions
rule "terraform_documented_outputs" {
  enabled = true
}

# Disallow // comments (use # instead — Terraform standard)
rule "terraform_comment_syntax" {
  enabled = true
}
