################################################################################
# FILE         : backend.tf
# DESCRIPTION  : Terraform S3 Remote Backend configuration with DynamoDB
#                state locking and AES-256 server-side encryption.
#
# ENTERPRISE STANDARD:
#   Local backends are strictly prohibited in production environments.
#   The S3 remote backend provides:
#     1. Centralized state storage   — accessible by all team members and CI/CD
#     2. State locking via DynamoDB  — prevents concurrent modification corruption
#     3. State encryption at rest    — AES-256 SSE on all state file versions
#     4. Full audit trail            — S3 versioning retains every state revision
#     5. Disaster recovery           — state survives local machine failure
#
# PRE-REQUISITE:
#   The S3 bucket and DynamoDB table referenced below must be provisioned
#   BEFORE running 'terraform init' on this root module. Use the
#   bootstrap/ module for this one-time setup:
#
#     cd bootstrap/
#     terraform init
#     terraform apply
#     cd ..
#     terraform init   <-- now this will succeed
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
# MANAGED BY   : Terraform
################################################################################

terraform {

  ##############################################################################
  # S3 REMOTE BACKEND
  #
  # WHY S3:
  #   S3 is the AWS-native, battle-tested solution for Terraform state storage.
  #   It is used by thousands of enterprises globally and is the answer
  #   every AWS-focused interviewer expects when asked about remote backends.
  #
  # IMPORTANT CONSTRAINT — NO VARIABLES IN BACKEND BLOCKS:
  #   Terraform backend blocks are processed during 'terraform init' —
  #   BEFORE variables are loaded. This means you CANNOT use var.* or
  #   local.* expressions here. All values must be literal strings.
  #   This is one of the most common mistakes junior engineers make.
  #
  #   The bucket name below uses the naming convention:
  #   <project>-tfstate-<environment>-<aws-account-id-suffix>
  #   You will update this value after running the bootstrap module.
  ##############################################################################
  backend "s3" {

    ############################################################################
    # S3 BUCKET — STATE FILE STORAGE
    #
    # ACTION REQUIRED:
    #   After running 'cd bootstrap && terraform apply', the bootstrap module
    #   will output the exact bucket name. Replace the placeholder below
    #   with that output value before running 'terraform init'.
    #
    #   The bucket name follows this convention:
    #   enterprise-tfstate-<random_suffix>
    #   Example: enterprise-tfstate-a3f8c2d1
    ############################################################################
    bucket = "enterprise-tfstate-REPLACE-AFTER-BOOTSTRAP"

    ############################################################################
    # STATE FILE KEY — PATH WITHIN THE BUCKET
    #
    # This is the "file path" of the state file inside the S3 bucket.
    # Using a structured path allows a SINGLE S3 bucket to store state
    # for multiple environments and projects — enterprise best practice.
    #
    # PATH CONVENTION:
    #   <project-name>/<environment>/terraform.tfstate
    #
    # This means:
    #   Production  : aws-enterprise-3tier/prod/terraform.tfstate
    #   Staging     : aws-enterprise-3tier/staging/terraform.tfstate
    #   Development : aws-enterprise-3tier/dev/terraform.tfstate
    #
    # All environments share one bucket — separated by key path — which
    # is simpler to manage and audit than one bucket per environment.
    ############################################################################
    key = "aws-enterprise-3tier/prod/terraform.tfstate"

    ############################################################################
    # REGION — WHERE THE S3 BUCKET LIVES
    #
    # The backend bucket region is independent of where your infrastructure
    # is deployed. Both can be the same region (as here) or different regions
    # for cross-region DR state storage.
    ############################################################################
    region = "ap-south-1"

    ############################################################################
    # ENCRYPTION — AES-256 SERVER-SIDE ENCRYPTION
    #
    # Setting encrypt = true instructs Terraform to use S3 server-side
    # encryption (SSE-S3, AES-256) for the state file at rest.
    #
    # WHY THIS IS CRITICAL:
    #   Terraform state files contain SENSITIVE DATA in plaintext:
    #     - Database passwords
    #     - Private IP addresses
    #     - IAM role ARNs
    #     - Resource IDs attackers could target
    #   Encryption at rest is a mandatory control in SOC2, PCI-DSS,
    #   and ISO 27001 compliance frameworks.
    ############################################################################
    encrypt = true

    ############################################################################
    # DYNAMODB TABLE — STATE LOCKING
    #
    # The DynamoDB table prevents concurrent Terraform operations from
    # corrupting the state file. Here is what happens:
    #
    # ENGINEER A runs 'terraform apply':
    #   1. Terraform writes a LOCK record to DynamoDB with a unique ID.
    #   2. Terraform reads current state from S3.
    #   3. Terraform applies changes to AWS.
    #   4. Terraform writes updated state back to S3.
    #   5. Terraform DELETES the lock record from DynamoDB.
    #
    # ENGINEER B runs 'terraform apply' WHILE Engineer A is running:
    #   1. Terraform tries to write a LOCK record to DynamoDB.
    #   2. DynamoDB rejects it — lock already exists.
    #   3. Terraform prints: "Error: state is locked by another process"
    #   4. Engineer B must wait or use 'terraform force-unlock' (with caution).
    #
    # The DynamoDB table requires a primary key named exactly 'LockID'.
    # This is a Terraform convention — not configurable.
    ############################################################################
    dynamodb_table = "enterprise-terraform-state-lock"

    ############################################################################
    # S3 BUCKET VERSIONING NOTE
    #
    # S3 versioning will be ENABLED on this bucket by the bootstrap module.
    # This means every 'terraform apply' creates a new version of the state
    # file in S3. Benefits:
    #
    #   1. ROLLBACK : If a bad apply corrupts state, you can restore a
    #                 previous version from the S3 console in seconds.
    #   2. AUDIT    : Every state change is recorded with a timestamp and
    #                 the IAM identity that triggered it via S3 access logs.
    #   3. DEBUGGING: Compare state versions to understand what changed
    #                 between two 'terraform apply' runs.
    ############################################################################

  }

}
