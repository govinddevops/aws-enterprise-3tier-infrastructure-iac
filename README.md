<div align="center">

# 🏗️ AWS Enterprise 3-Tier Production Infrastructure
## Infrastructure as Code — Powered by Terraform

<br/>

![Terraform](https://img.shields.io/badge/Terraform-1.6+-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Provider_5.x-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Amazon Linux](https://img.shields.io/badge/Amazon_Linux-2023-FF9900?style=for-the-badge&logo=amazon&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Free Tier](https://img.shields.io/badge/AWS_Free_Tier-Compliant-brightgreen?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Production_Ready-success?style=for-the-badge)
![IaC](https://img.shields.io/badge/IaC-100%25_Automated-blue?style=for-the-badge)

<br/>

> ### *"Zero hardcoded values. Zero manual clicks. Zero compromise on security."*
> Every resource provisioned, secured, tagged, and destroyed through code alone.

<br/>

**⭐ If this repository helped you, please consider giving it a star! ⭐**

</div>

---

## 📋 Table of Contents

- [🎯 Project Overview](#-project-overview)
- [🏛️ Architecture Overview](#️-architecture-overview)
- [🌐 High Availability Design](#-high-availability-design)
- [📁 Directory Structure](#-directory-structure)
- [🛡️ Security Standards](#️-security-standards)
- [🗄️ State Management](#️-state-management)
- [📦 Module Reference](#-module-reference)
- [🌍 Environment Strategy](#-environment-strategy)
- [💰 Cost Analysis](#-cost-analysis)
- [⚙️ Prerequisites](#️-prerequisites)
- [🚀 Deployment Guide](#-deployment-guide)
- [🔧 Common Operations](#-common-operations)
- [🛠️ Technologies Used](#️-technologies-used)
- [👤 Author](#-author)

---

## 🎯 Project Overview

This repository delivers a **complete, production-grade AWS 3-Tier Architecture**
provisioned entirely through Terraform — from network foundation to application
servers to an encrypted, isolated database layer.

Every pattern implemented here reflects real-world enterprise standards used
by cloud engineering teams at scale — modular design, remote state management,
least-privilege IAM, auto-scaling compute, and zero hardcoded credentials.

### 🏆 What Makes This Enterprise-Grade?

| ✅ Standard | ⚙️ Implementation |
|---|---|
| 🔒 Zero Hardcoded Credentials | IAM Instance Profiles + AWS Secrets Manager runtime retrieval |
| 🗄️ Remote State Management | S3 backend with AES-256 encryption + versioning |
| 🔐 Distributed State Locking | DynamoDB prevents concurrent apply corruption |
| 🏷️ Automatic Compliance Tagging | Provider-level `default_tags` stamps every resource |
| 🛡️ Layered Network Security | 3-tier Security Group chain with SG-to-SG referencing |
| 📦 Modular Architecture | 6 isolated, reusable modules with clean input/output contracts |
| 🔄 Auto Scaling Compute | CPU-based ASG policies with CloudWatch alarms |
| 🌍 Multi-Environment Support | Dev / Staging / Production isolated via tfvars |
| ✅ Input Validation | Validation blocks catch misconfiguration before any API call |
| 🔐 IMDSv2 Enforced | SSRF-proof metadata service on every EC2 instance |
| 💾 Encryption Everywhere | EBS gp3 + RDS AES-256 + S3 state — at rest and in transit |
| 🚫 No Console Clicks | Every resource created, modified, and destroyed via code only |

---

## 🏛️ Architecture Overview
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AWS CLOUD — ap-south-1 (Mumbai)                      │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        VPC  —  10.0.0.0/16                             │ │
│  │                                                                        │ │
│  │  ╔══════════════════════════════════════════════════════════════════╗  │ │
│  │  ║              🌐  TIER 1 — PUBLIC SUBNETS                         ║  │ │
│  │  ║                                                                  ║  │ │
│  │  ║   ┌─────────────────────────┐  ┌─────────────────────────┐       ║  │ │
│  │  ║   │  AZ-a  10.0.1.0/24      │  │  AZ-b  10.0.2.0/24      │       ║  │ │
│  │  ║   │  ┌───────────────────┐  │  │  ┌───────────────────┐  │       ║  │ │
│  │  ║   │  │   NAT Gateway     │  │  │  │  (optional NAT)   │  │       ║  │ │
│  │  ║   │  │   Elastic IP      │  │  │  │                   │  │       ║  │ │
│  │  ║   │  └───────────────────┘  │  │  └───────────────────┘  │       ║  │ │
│  │  ║   └────────────┬────────────┘  └─────────────┬───────────┘       ║  │ │
│  │  ║                │                              │                  ║  │ │
│  │  ║   ┌────────────▼──────────────────────────────▼───────────────┐  ║  │ │
│  │  ║   │         ⚖️  Application Load Balancer (Internet-Facing)   │  ║  │ │
│  │  ║   │              Ports: 80 (HTTP) · 443 (HTTPS)               │  ║  │ │
│  │  ║   │              Cross-Zone Load Balancing ✅                 │  ║  │ │
│  │  ║   │              Health Checks: GET /health every 30s         │  ║  │ │
│  │  ║   └────────────────────────────┬──────────────────────────────┘  ║  │ │
│  │  ╚════════════════════════════════│═════════════════════════════════╝  │ │
│  │                                   │ Port 80 only                       │ │
│  │                                   │ SG-to-SG Reference                 │ │
│  │  ╔════════════════════════════════│═════════════════════════════════╗  │ │
│  │  ║          💻  TIER 2 — PRIVATE SUBNETS (Application)              ║  │ │
│  │  ║                                │                                 ║  │ │
│  │  ║   ┌────────────────────────────▼────────────────────────────┐    ║  │ │
│  │  ║   │              🔄  Auto Scaling Group                     |    ║  │ │
│  │  ║   │         min: 1  ·  desired: 2  ·  max: 2                │    ║  │ │
│  │  ║   │                                                         │    ║  │ │
│  │  ║   │  ┌──────────────────────┐  ┌──────────────────────┐     │    ║  │ │
│  │  ║   │  │  EC2  t2.micro       │  │  EC2  t2.micro       │     │    ║  │ │
│  │  ║   │  │  AZ-a 10.0.10.0/24  │  │  AZ-b 10.0.11.0/24    │     │    ║  │ │
│  │  ║   │  │  Amazon Linux 2023  │  │  Amazon Linux 2023    │     |    ║  │ │
│  │  ║   │  │  IMDSv2       ✅    │  │  IMDSv2       ✅      │     │    ║  │ │
│  │  ║   │  │  EBS Encrypted ✅   │  │  EBS Encrypted ✅     │     │    ║  │ │
│  │  ║   │  │  IAM Role      ✅   │  │  IAM Role      ✅     │     │    ║  │ │
│  │  ║   │  │  gp3  15 GiB       │  │  gp3  15 GiB           │     │    ║  │ │
│  │  ║   │  └──────────────────────┘  └──────────────────────┘     │    ║  │ │
│  │  ║   └──────────────────────────────────────────────────────── ┘    ║  │ │
│  │  ╚══════════════════════════════════════════════════════════════════╝  │ │
│  │                                   │ Port 3306 only                     │ │
│  │                                   │ SG-to-SG Reference                 │ │
│  │  ╔════════════════════════════════│═════════════════════════════════╗  │ │
│  │  ║       🗄️  TIER 3 — DATABASE SUBNETS (Fully Isolated)              ║  │ │
│  │  ║                                │                                 ║  │ │
│  │  ║   ┌────────────────────────────▼────────────────────────────┐    ║  │ │
│  │  ║   │  ┌──────────────────────┐  ┌──────────────────────┐     │    ║  │ │
│  │  ║   │  │  RDS MySQL 8.0       │  │  Standby (Multi-AZ)  │     │    ║  │ │
│  │  ║   │  │  db.t3.micro         │  │  Optional            │     │    ║  │ │
│  │  ║   │  │  AZ-a 10.0.20.0/24   │  │  AZ-b 10.0.21.0/24   │     │    ║  │ │
│  │  ║   │  │  AES-256     ✅      │  │  Auto Failover  ✅   │     │    ║  │ │
│  │  ║   │  │  TLS Transit ✅      │  │  < 60s RTO           │     │    ║  │ │
│  │  ║   │  │  No Internet ✅      │  │                      │     │    ║  │ │
│  │  ║   │  │  20 GiB gp2          │  │                      │     │    ║  │ │
│  │  ║   │  └──────────────────────┘  └──────────────────────┘     │    ║  │ │
│  │  ║   └──────────────────────────────────────────────────────── ┘    ║  │ │
│  │  ╚══════════════════════════════════════════════════════════════════╝  │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────┐
                │      🌐  Internet Gateway           │
                │      Connected to VPC               │
                │      Public Route: 0.0.0.0/0 → IGW  │
                └─────────────────────────────────────┘

                ┌─────────────────────────────────────┐
                │     🗄️  Terraform Remote State       │
                │                                     │
                │  S3 Bucket  : enterprise-tfstate-XX │
                │  Encryption : AES-256    ✅         │
                │  Versioning : Enabled    ✅         │
                │  Public Block: Blocked   ✅         │
                │  DynamoDB   : State Lock ✅         │
                │  Lifecycle  : 30-day retention ✅   │
                └─────────────────────────────────────┘

---

## 🌐 High Availability Design

The infrastructure is engineered for **fault tolerance at every layer**:

### 🔁 Multi-AZ Deployment Strategy
Availability Zone A (ap-south-1a)        Availability Zone B (ap-south-1b)
─────────────────────────────────        ─────────────────────────────────
Public  Subnet : 10.0.1.0/24             Public  Subnet : 10.0.2.0/24
Private Subnet : 10.0.10.0/24            Private Subnet : 10.0.11.0/24
Database Subnet: 10.0.20.0/24            Database Subnet: 10.0.21.0/24
NAT Gateway #1 (Primary)                 NAT Gateway #2 (optional HA)
EC2 Instance #1                          EC2 Instance #2
RDS Primary                              RDS Standby (Multi-AZ option)

### 🛡️ Failure Scenario Handling

| Failure Scenario | System Response | Recovery Time |
|---|---|---|
| Single EC2 instance fails | ASG detects via ELB health check, launches replacement in same AZ | 3-5 minutes |
| Full AZ failure | ALB routes 100% traffic to healthy AZ, ASG launches replacement | < 60 seconds |
| High CPU on all instances | CloudWatch alarm triggers scale-out policy, new instance added | 3-5 minutes |
| RDS primary failure (Multi-AZ) | Automatic failover to standby replica | < 60 seconds |
| NAT Gateway failure (single) | Private instances lose outbound internet until resolved | Manual intervention |
| NAT Gateway failure (per-AZ) | AZ-local NAT route fails, other AZ unaffected | 0 seconds |

### ⚖️ Load Balancer Design

Browser Request
│
▼
Route 53 (optional custom domain)
│
▼
Application Load Balancer (internet-facing)
├── HTTP Listener  (port 80)  → Forward to Target Group
├── HTTPS Listener (port 443) → Forward to Target Group (with ACM cert)
├── Cross-Zone Load Balancing → ON (no additional cost on ALB)
├── HTTP/2                    → Enabled
├── Idle Timeout              → 60 seconds
└── Deregistration Delay      → 30 seconds (graceful drain)
│
▼
Target Group
├── Health Check: GET /health every 30s
├── Healthy Threshold   : 2 consecutive passes
├── Unhealthy Threshold : 3 consecutive failures
├── Timeout             : 5 seconds
└── Matcher             : HTTP 200-299
│
┌─────┴─────┐
▼           ▼
EC2 (AZ-a)  EC2 (AZ-b)


### 📈 Auto Scaling Design
CloudWatch Alarm: CPU > 70% for 2 consecutive minutes
│
▼
Scale-Out Policy → Add 1 instance → Cooldown 300s
CloudWatch Alarm: CPU < 30% for 5 consecutive minutes
│
▼
Scale-In Policy → Remove 1 instance → Cooldown 300s
ASG Boundaries:
min_size         = 1   ← Always at least 1 instance running
desired_capacity = 2   ← Normal operating state
max_size         = 2   ← Hard cost ceiling (Free Tier)
Instance Refresh (zero-downtime deployments):
Strategy             = Rolling
MinHealthyPercentage = 50%  → Replace 1 at a time
InstanceWarmup       = 300s → Wait for app to fully start

---

## 📁 Directory Structure
aws-enterprise-3tier-infrastructure-iac/
│
├── 📄 backend.tf                    # S3 remote backend + DynamoDB state locking
├── 📄 providers.tf                  # AWS provider config + enterprise default_tags
├── 📄 versions.tf                   # Terraform core + provider version pinning
├── 📄 main.tf                       # Root orchestrator — calls all 6 child modules
├── 📄 variables.tf                  # All root inputs with type + validation blocks
├── 📄 outputs.tf                    # Post-apply resource IDs, URLs, and summary
├── 📄 terraform.tfvars              # Production configuration values (default)
├── 📄 .gitignore                    # Excludes state files, secrets, and plugins
├── 📄 README.md                     # This file — professional project documentation
│
├── 🔧 bootstrap/                    # ⚠️  ONE-TIME SETUP — run BEFORE root module
│   ├── 📄 versions.tf               # Local backend (S3 does not exist yet)
│   ├── 📄 variables.tf              # Region + project name inputs
│   ├── 📄 main.tf                   # Creates S3 bucket + DynamoDB lock table
│   └── 📄 outputs.tf               # Prints exact bucket name to paste in backend.tf
│
├── 🌍 environments/                 # Environment-specific variable overrides
│   ├── dev/
│   │   └── 📄 terraform.tfvars     # Dev: no NAT GW · 1 instance · no protection
│   ├── staging/
│   │   └── 📄 terraform.tfvars     # Staging: NAT enabled · 2 instances · protected
│   └── prod/
│       └── 📄 terraform.tfvars     # Prod: all protections · max reliability
│
└── 📦 modules/                      # Reusable infrastructure modules
│
├── vpc/                         # Network foundation
│   ├── 📄 main.tf               # VPC · 6 subnets · IGW · NAT GW · route tables · DB subnet group
│   ├── 📄 variables.tf          # CIDR blocks · AZs · NAT configuration
│   └── 📄 outputs.tf            # vpc_id · subnet IDs · nat IPs · route table IDs
│
├── security_groups/             # 3-tier firewall chain
│   ├── 📄 main.tf               # ALB SG · App SG · DB SG with SG-to-SG rules
│   ├── 📄 variables.tf          # vpc_id · allowed CIDRs · db port
│   └── 📄 outputs.tf            # alb_sg_id · app_sg_id · db_sg_id
│
├── alb/                         # Application Load Balancer
│   ├── 📄 main.tf               # ALB · Target Group · HTTP Listener
│   ├── 📄 variables.tf          # vpc_id · subnets · SG · health check config
│   └── 📄 outputs.tf            # alb_dns_name · alb_arn · target_group_arn
│
├── iam/                         # Identity and access management
│   ├── 📄 main.tf               # EC2 Role · 4 policies · Instance Profile
│   ├── 📄 variables.tf          # project_name · region · permission toggles
│   └── 📄 outputs.tf            # instance_profile_name · ec2_role_arn
│
├── compute/                     # EC2 Auto Scaling application tier
│   ├── 📄 main.tf               # AMI data · Launch Template · ASG · scaling · alarms
│   ├── 📄 variables.tf          # instance_type · ami_id · asg sizing · cpu thresholds
│   ├── 📄 outputs.tf            # asg_name · launch_template_id · ami_id_used
│   └── templates/
│       └── 📄 user_data.sh      # EC2 bootstrap: Apache install + health endpoint
│
└── rds/                         # Managed database tier
├── 📄 main.tf               # Random password · Secrets Manager · Parameter Group · RDS
├── 📄 variables.tf          # Engine · instance class · backup · monitoring config
└── 📄 outputs.tf            # db_secret_arn · db_endpoint · db_instance_id

**Total: 34 files · 13 directories · ~2,500 lines of production Terraform**

---

## 🛡️ Security Standards

### 🔐 3-Tier Firewall Chain — Principle of Least Privilege

🌐 Internet
│
│  ports 80, 443 from 0.0.0.0/0
▼
┌─────────────────────────────────────────────────┐
│  🔵  ALB Security Group                         │
│                                                 │
│  INBOUND:                                       │
│    ✅ TCP 80  from 0.0.0.0/0  (HTTP)            │
│    ✅ TCP 443 from 0.0.0.0/0  (HTTPS)           │
│    ❌ Everything else → DENIED                  │
│                                                 │
│  OUTBOUND:                                      │
│    ✅ All traffic to VPC (forward to EC2)       │
└──────────────────────┬──────────────────────────┘
│
│  port 80 — SG-to-SG reference
│  Source = ALB Security Group ID
│  (NOT a CIDR block — cannot be spoofed)
▼
┌─────────────────────────────────────────────────┐
│  🟡  App Security Group (EC2 Instances)         │
│                                                 │
│  INBOUND:                                       │
│    ✅ TCP 80 from ALB SG ID only                │
│    ✅ TCP 22 from VPC CIDR only (Bastion/SSM)   │
│    ❌ Everything else → DENIED                  │
│    ❌ Direct internet access → IMPOSSIBLE       │
│                                                 │
│  OUTBOUND:                                      │
│    ✅ All traffic (OS updates via NAT GW)       │
└──────────────────────┬──────────────────────────┘
│
│  port 3306 — SG-to-SG reference
│  Source = App Security Group ID
│  (Only EC2 instances can reach RDS)
▼
┌─────────────────────────────────────────────────┐
│  🔴  DB Security Group (RDS Instances)          │
│                                                 │
│  INBOUND:                                       │
│    ✅ TCP 3306 from App SG ID only              │
│    ❌ Everything else → DENIED                  │
│    ❌ Internet access → IMPOSSIBLE              │
│    ❌ Even VPC-wide CIDR access → DENIED        │
│                                                 │
│  OUTBOUND:                                      │
│    ✅ VPC CIDR only (no internet exfiltration)  │
└─────────────────────────────────────────────────┘

### 🔒 Security Controls Matrix

| 🛡️ Control | ⚙️ Implementation | 📋 Compliance Standard |
|---|---|---|
| No hardcoded secrets | IAM Instance Profile + Secrets Manager | CIS AWS Benchmark |
| Encryption at rest — EC2 | EBS gp3 volumes encrypted AES-256 | SOC2 CC6.1 |
| Encryption at rest — RDS | `storage_encrypted = true` AES-256 | SOC2 CC6.1 |
| Encryption at rest — State | S3 SSE AES-256 on every state version | Internal Policy |
| Encryption in transit — DB | `require_secure_transport = ON` parameter | PCI-DSS 4.1 |
| IMDSv2 enforced | `http_tokens = required`, hop limit = 1 | CIS AWS 5.6 |
| Least privilege IAM | Scoped resource ARNs — zero wildcard `*` | ISO 27001 A.9 |
| No public database | `publicly_accessible = false` | CIS AWS 2.3 |
| State encryption | S3 AES-256 + versioning + public block | Internal Policy |
| Concurrent apply lock | DynamoDB `LockID` primary key | Internal Policy |
| SG-to-SG referencing | Source SG ID — not CIDR blocks | AWS Best Practice |
| Auto minor patching | `auto_minor_version_upgrade = true` | CIS AWS 2.2 |
| SSH blocked from internet | Port 22 restricted to VPC CIDR only | CIS AWS 5.2 |
| SSM Session Manager | IAM-controlled SSH-free shell access | AWS Best Practice |
| Slow query logging | `slow_query_log = 1`, threshold 2s | Internal Observability |
| Disable LOCAL INFILE | `local_infile = 0` in parameter group | MySQL CIS Benchmark |
| S3 public access block | All 4 public access block settings ON | CIS AWS 2.1 |
| Lifecycle — old state | Non-current versions deleted after 30 days | Cost + Security |
| Tag compliance | Provider `default_tags` — zero untagged resources | FinOps + Audit |

### 🔑 Credential Management — Zero Secrets in Code
HOW THE DATABASE PASSWORD WORKS:
Step 1 → Terraform generates a 32-character random password internally
resource "random_password" "db_password" { length = 32 }
Step 2 → Password stored directly in AWS Secrets Manager
Path: enterprise-3tier/prod/rds/master-password
Format: JSON { username, password, dbname, engine }
Step 3 → RDS instance created using the generated password
password = random_password.db_password.result
Step 4 → EC2 application retrieves credentials at runtime
SDK call → secretsmanager:GetSecretValue
Authenticated via IAM Instance Profile (no keys needed)
RESULT:
✅ Password never in any .tf file
✅ Password never in terraform.tfvars
✅ Password never in Git history
✅ Password never in CI/CD logs
✅ Password rotates without code changes
✅ Access controlled by IAM policy (scoped ARN)
---

## 🗄️ State Management

### The Remote Backend Architecture
┌─────────────────────────────────────────────────────────────────┐
│                    TERRAFORM STATE FLOW                         │
│                                                                 │
│  Engineer A runs: terraform apply                               │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Step 1: Terraform writes LOCK record to DynamoDB       │    │
│  │          { LockID: "enterprise-3tier/prod/...",         │    │
│  │            Operation: "OperationTypeApply",             │    │
│  │            Who: "engineer-a@company.com" }              │    │
│  └─────────────────────────┬───────────────────────────────┘    │
│                             │                                   │
│  Engineer B runs: terraform apply (at the same time)            │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  DynamoDB REJECTS Engineer B's lock attempt             │    │ 
│  │  Error: "state is currently locked by another process"  │    │
│  │  Engineer B must wait for A to complete                 │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Engineer A's apply completes:                                  │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Step 2: Updated state written to S3 as new version     │    │
│  │  Step 3: DynamoDB LOCK record deleted                   │    │
│  │  Step 4: Engineer B can now acquire lock and proceed    │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
### S3 State Bucket — Enterprise Configuration

aws_s3_bucket "terraform_state"
│
├── Versioning           : ENABLED
│     Every terraform apply = new state version stored
│     Accidental corruption? Restore previous version in seconds
│
├── Server-Side Encryption: AES-256 (SSE-S3)
│     State file contains RDS passwords, IPs, ARNs in plaintext
│     Encryption at rest is non-negotiable
│
├── Public Access Block  : ALL FOUR SETTINGS = TRUE
│     block_public_acls       = true
│     block_public_policy     = true
│     ignore_public_acls      = true
│     restrict_public_buckets = true
│
├── Lifecycle Policy     : Non-current versions → deleted after 30 days
│     Prevents unbounded storage growth from thousands of state versions
│
└── Force Destroy        : false
Prevents accidental deletion of all state history

### DynamoDB Lock Table — Configuration

aws_dynamodb_table "terraform_state_lock"
│
├── Primary Key    : LockID (String) — Terraform convention, non-configurable
├── Billing Mode   : PAY_PER_REQUEST — fractions of a cent per apply
├── PITR           : Enabled — point-in-time recovery for the lock table itself
├── SSE            : Enabled — lock records encrypted at rest
└── Cost           : < $0.01/month for typical Terraform usage

### The Bootstrap Dependency Chain

PROBLEM: backend.tf references an S3 bucket that doesn't exist yet.
terraform init fails because it cannot connect to the backend.
SOLUTION: Two-phase deployment using a separate bootstrap module.
PHASE 1 — Bootstrap Module (local backend — runs ONCE):
cd bootstrap/
terraform init    ← uses local backend, no S3 needed
terraform apply   ← creates S3 bucket + DynamoDB table
terraform output  ← prints exact bucket name with random suffix
PHASE 2 — Root Module (S3 backend — runs forever after):
← Update backend.tf with real bucket name from Phase 1 output
terraform init    ← now connects to S3 backend successfully
terraform apply   ← all state stored remotely from this point forward
WHY bootstrap uses local state:
← Only 2 resources (S3 + DynamoDB) — minimal state to manage locally
← These resources almost never change after initial creation
← bootstrap/terraform.tfstate is excluded via .gitignore
← Manual backup: aws s3 cp bootstrap/terraform.tfstate s3://your-backup/

---

## 📦 Module Reference

### 🌐 VPC Module — `modules/vpc/`

**Provisions:** VPC · Internet Gateway · 2 Public Subnets · 2 Private Subnets · 2 Database Subnets · NAT Gateway(s) · Route Tables (public/private/database) · Route Table Associations · RDS DB Subnet Group

| Variable | Description | Default |
|---|---|---|
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `public_subnet_cidrs` | Public subnet CIDRs list | `[10.0.1.0/24, 10.0.2.0/24]` |
| `private_subnet_cidrs` | Private subnet CIDRs list | `[10.0.10.0/24, 10.0.11.0/24]` |
| `database_subnet_cidrs` | DB subnet CIDRs list | `[10.0.20.0/24, 10.0.21.0/24]` |
| `availability_zones` | AZ names list | `[ap-south-1a, ap-south-1b]` |
| `enable_nat_gateway` | Provision NAT Gateway | `true` |
| `single_nat_gateway` | One shared vs per-AZ NAT | `true` |

| Output | Description |
|---|---|
| `vpc_id` | VPC identifier — consumed by all other modules |
| `public_subnet_ids` | ALB placement — list across all AZs |
| `private_subnet_ids` | EC2 ASG placement — list across all AZs |
| `database_subnet_ids` | RDS placement — fully isolated |
| `db_subnet_group_name` | RDS subnet group name |
| `nat_gateway_public_ips` | Whitelist in external API allowlists |

---

### 🔒 Security Groups Module — `modules/security_groups/`

**Provisions:** ALB Security Group · Application Security Group · Database Security Group · All ingress/egress rules using separate `aws_security_group_rule` resources

| Output | Description |
|---|---|
| `alb_sg_id` | Attach to Application Load Balancer |
| `app_sg_id` | Attach to EC2 Launch Template |
| `db_sg_id` | Attach to RDS instance |
| `security_group_summary` | Map of all 3 SG IDs for reference |

---

### ⚖️ ALB Module — `modules/alb/`

**Provisions:** Application Load Balancer (internet-facing) · Target Group with health checks · HTTP Listener on port 80 · Cross-zone load balancing · Connection draining

| Output | Description |
|---|---|
| `alb_dns_name` | Application URL — paste in browser after apply |
| `alb_arn` | ARN for WAF and CloudWatch alarm association |
| `target_group_arn` | ASG registers instances here automatically |
| `alb_zone_id` | Route 53 alias record zone ID |
| `application_url` | Full `http://` URL ready to open |

---

### 👤 IAM Module — `modules/iam/`

**Provisions:** EC2 IAM Role (EC2 trust policy) · S3 read policy (project-scoped ARNs) · Secrets Manager read policy (project-scoped ARNs) · CloudWatch publish policy (project-scoped) · SSM Session Manager managed policy attachment · EC2 Instance Profile

| Output | Description |
|---|---|
| `instance_profile_name` | Attach to EC2 Launch Template |
| `ec2_role_arn` | Add as principal in S3 bucket policies |
| `s3_policy_arn` | Reuse in other roles if needed |
| `secrets_manager_policy_arn` | Reuse in other roles if needed |

---

### 💻 Compute Module — `modules/compute/`

**Provisions:** AMI data source (latest Amazon Linux 2023) · EC2 Launch Template (IMDSv2, encrypted EBS, user data) · Auto Scaling Group (multi-AZ) · Scale-out policy · Scale-in policy · High CPU CloudWatch alarm · Low CPU CloudWatch alarm

| Output | Description |
|---|---|
| `autoscaling_group_name` | CI/CD instance refresh target |
| `launch_template_id` | EC2 blueprint identifier |
| `launch_template_latest_version` | Confirm current config version |
| `ami_id_used` | Resolved Amazon Linux 2023 AMI ID |
| `scale_out_policy_arn` | Reference in external alarms |

---

### 🗄️ RDS Module — `modules/rds/`

**Provisions:** Random password (32 chars, lifecycle-protected) · Secrets Manager secret container · Secret version (JSON with username/password/dbname/engine) · Custom MySQL 8.0 Parameter Group · RDS DB Instance

| Output | Description |
|---|---|
| `db_secret_arn` | App calls GetSecretValue with this ARN |
| `db_secret_name` | Human-readable secret path |
| `db_instance_endpoint` | Connection hostname (marked sensitive) |
| `db_instance_port` | MySQL port 3306 |
| `db_instance_id` | CloudWatch metric dimension |
| `db_parameter_group_name` | Reference for read replicas |

---

## 🌍 Environment Strategy

┌──────────────────┬─────────────────┬─────────────────┬─────────────────────┐
│  Configuration   │       DEV       │    STAGING      │     PRODUCTION      │
├──────────────────┼─────────────────┼─────────────────┼─────────────────────┤
│ VPC CIDR         │ 10.1.0.0/16     │ 10.2.0.0/16     │ 10.0.0.0/16         │
│ EC2 Instances    │ desired = 1     │ desired = 2     │ desired = 2         │
│ ASG Min/Max      │ 1 / 2           │ 1 / 3           │ 1 / 2               │
│ NAT Gateway      │ ❌ Disabled     │ ✅ Enabled      │ ✅ Enabled          │
│ Multi-AZ RDS     │ ❌ No           │ ❌ No           │ ❌ Cost opt         │
│ ALB Del. Protect │ ❌ Off          │ ✅ On           │ ✅ On               │
│ DB Del. Protect  │ ❌ Off          │ ✅ On           │ ✅ On               │
│ Final Snapshot   │ ❌ Skip         │ ✅ Take         │ ✅ Take             │
│ Backup Retention │ 1 day           │ 7 days          │ 7 days              │
│ Scale-Out CPU    │ 60%             │ 60%             │ 70%                 │
│ Scale-In CPU     │ 20%             │ 25%             │ 30%                 │
│ Monthly Cost     │ ~$16            │ ~$48            │ ~$48                │
└──────────────────┴─────────────────┴─────────────────┴─────────────────────┘

```bash
# Deploy to specific environment
terraform apply -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/staging/terraform.tfvars
terraform apply                                                # defaults to prod
```

**Why different VPC CIDRs per environment?**
Each environment uses a unique /16 block (10.0, 10.1, 10.2). This allows
future VPC peering between environments without CIDR overlap conflicts —
a forward-thinking design decision that costs nothing now and saves days
of rework later.

---

## 💰 Cost Analysis

### Production Environment Estimate

| Resource | Type | Free Tier | Est. Monthly Cost |
|---|---|---|---|
| EC2 Application Servers × 2 | t2.micro | ✅ 750 hrs/month | $0 *(first 12 months)* |
| RDS Database × 1 | db.t3.micro | ✅ 750 hrs/month | $0 *(first 12 months)* |
| EBS Root Volumes × 2 | gp3 15 GiB each | ✅ 30 GiB/month | $0 *(first 12 months)* |
| Application Load Balancer | ALB | ❌ Not Free Tier | ~$16/month |
| NAT Gateway × 1 | Shared (single) | ❌ Not Free Tier | ~$32/month |
| S3 State Bucket | < 1 MB storage | ✅ 5 GB free | ~$0.01/month |
| DynamoDB Lock Table | PAY_PER_REQUEST | ✅ 25 GB free | ~$0.00/month |
| Secrets Manager | 1 secret | — | ~$0.40/month |
| CloudWatch Alarms | 2 alarms | ✅ 10 free alarms | $0 |
| **Total Estimate** | | | **~$48/month** |

> ⚠️ **Cost Optimisation Tip:** Run `terraform destroy` when not actively testing.
> All billable resources are removed in under 5 minutes.
> The S3 state bucket and DynamoDB table cost < $0.01/month to keep alive
> between deployments — leave these running permanently.

---

## ⚙️ Prerequisites

### 1️⃣ Install Terraform

```bash
# Download from https://developer.hashicorp.com/terraform/install
# Ubuntu / Debian
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify
terraform version
# Expected: Terraform v1.6.x or higher
```

### 2️⃣ Install AWS CLI

```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version
# Expected: aws-cli/2.x.x
```

### 3️⃣ Configure AWS Credentials

```bash
# Configure with your IAM user credentials
aws configure

# You will be prompted for:
# AWS Access Key ID     : (from IAM Console → Users → Security Credentials)
# AWS Secret Access Key : (shown once at creation — store securely)
# Default region name   : ap-south-1
# Default output format : json

# Verify identity
aws sts get-caller-identity
# Expected: JSON with Account, UserId, Arn
```

### 4️⃣ Create EC2 Key Pair

```bash
# Create key pair in AWS
aws ec2 create-key-pair \
  --key-name enterprise-key \
  --query 'KeyMaterial' \
  --output text \
  --region ap-south-1 > ~/.ssh/enterprise-key.pem

# Secure permissions — SSH refuses to use keys with open permissions
chmod 400 ~/.ssh/enterprise-key.pem

# Verify
ls -la ~/.ssh/enterprise-key.pem
# Expected: -r-------- 1 user user XXXX enterprise-key.pem
```

### 5️⃣ Clone the Repository

```bash
# Clone
git clone https://github.com/YOUR-USERNAME/aws-enterprise-3tier-infrastructure-iac.git

# Navigate
cd aws-enterprise-3tier-infrastructure-iac

# Verify structure
find . -type f | grep -v ".terraform" | sort
```

---

## 🚀 Deployment Guide

### 🔧 PHASE 1 — Bootstrap (Run Once Only)

This phase provisions the S3 bucket and DynamoDB table that the main
infrastructure uses as its Terraform backend. It runs with a local backend
because the S3 bucket does not exist yet.

```bash
# Step 1: Navigate to bootstrap directory
cd bootstrap/

# Step 2: Initialise Terraform with local backend
terraform init

# Expected output:
# Initializing the backend...
# Initializing provider plugins...
# - Finding hashicorp/aws versions matching "~> 5.0"...
# - Installing hashicorp/aws v5.x.x...
# Terraform has been successfully initialized!

# Step 3: Preview what will be created (S3 bucket + DynamoDB table only)
terraform plan

# Step 4: Deploy backend infrastructure
terraform apply

# Type 'yes' when prompted
# Expected: Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

# Step 5: Capture the bucket name — you need this for the next step
terraform output s3_bucket_name

# Example output: "enterprise-3tier-tfstate-a3f8c2d1"

# Step 6: Also view the complete backend config block (convenience output)
terraform output backend_config_block

# Step 7: Return to project root
cd ..
```

### 📝 PHASE 2 — Configure Remote Backend

```bash
# Open backend.tf
nano backend.tf

# Find this line (around line 60):
#   bucket = "enterprise-tfstate-REPLACE-AFTER-BOOTSTRAP"

# Replace with the actual bucket name from Phase 1 output:
#   bucket = "enterprise-3tier-tfstate-a3f8c2d1"

# Save and close: CTRL+O → Enter → CTRL+X
```

### ▶️ PHASE 3 — Initialise Root Module

```bash
# Initialise with S3 remote backend
terraform init

# Expected output:
# Initializing the backend...
# Successfully configured the backend "s3"!
# Initializing modules...
# - vpc in modules/vpc
# - security_groups in modules/security_groups
# - alb in modules/alb
# - iam in modules/iam
# - compute in modules/compute
# - rds in modules/rds
# Terraform has been successfully initialized!
```

### ✅ PHASE 4 — Validate Configuration

```bash
# Validate all 34 files for syntax and logical correctness
terraform validate

# Expected output:
# Success! The configuration is valid.

# Format all files to canonical Terraform style
terraform fmt -recursive

# Expected output: (lists any files that were reformatted)
# providers.tf
# variables.tf
```

### 📋 PHASE 5 — Review Execution Plan

```bash
# Generate and display the complete execution plan
terraform plan

# Review the output carefully:
# Plan: ~45 to add, 0 to change, 0 to destroy.

# Resources you should see planned:
#   + aws_vpc.main
#   + aws_subnet.public[0]
#   + aws_subnet.public[1]
#   + aws_subnet.private[0]
#   + aws_subnet.private[1]
#   + aws_subnet.database[0]
#   + aws_subnet.database[1]
#   + aws_internet_gateway.main
#   + aws_eip.nat[0]
#   + aws_nat_gateway.main[0]
#   + aws_route_table.public
#   + aws_route_table.private[0]
#   + aws_route_table.database
#   + aws_route_table_association.public[0,1]
#   + aws_route_table_association.private[0,1]
#   + aws_route_table_association.database[0,1]
#   + aws_db_subnet_group.main
#   + aws_security_group.alb
#   + aws_security_group.app
#   + aws_security_group.db
#   + aws_security_group_rule.* (7 rules)
#   + aws_lb.main
#   + aws_lb_target_group.app
#   + aws_lb_listener.http
#   + aws_iam_role.ec2_role
#   + aws_iam_policy.* (3 policies)
#   + aws_iam_role_policy_attachment.* (4 attachments)
#   + aws_iam_instance_profile.ec2_profile
#   + aws_launch_template.app
#   + aws_autoscaling_group.app
#   + aws_autoscaling_policy.scale_out
#   + aws_autoscaling_policy.scale_in
#   + aws_cloudwatch_metric_alarm.cpu_high
#   + aws_cloudwatch_metric_alarm.cpu_low
#   + random_password.db_password
#   + aws_secretsmanager_secret.db_password
#   + aws_secretsmanager_secret_version.db_password
#   + aws_db_parameter_group.main
#   + aws_db_instance.main

# Optional: Save the plan to a file for auditability
terraform plan -out=tfplan.out
```

### 🚀 PHASE 6 — Deploy Infrastructure

```bash
# Apply the planned changes
terraform apply

# OR apply from saved plan file (skips second confirmation):
terraform apply tfplan.out

# Type 'yes' when prompted (if not using saved plan)

# Deployment timeline:
#   VPC + Subnets + IGW       : ~30 seconds
#   NAT Gateway               : ~60-90 seconds
#   Security Groups           : ~30 seconds
#   ALB + Target Group        : ~60 seconds
#   IAM Resources             : ~30 seconds
#   Launch Template + ASG     : ~60 seconds
#   RDS Instance              : ~8-10 minutes (longest step)
#   Secrets Manager           : ~10 seconds
#
#   TOTAL: approximately 10-15 minutes

# Expected final output:
# Apply complete! Resources: 45 added, 0 changed, 0 destroyed.
```

### ✅ PHASE 7 — Verify Deployment

```bash
# View all outputs
terraform output

# Get the application URL
terraform output alb_dns_name

# View the complete deployment summary
terraform output deployment_summary

# Test the application in your browser:
# http://<alb-dns-name>.ap-south-1.elb.amazonaws.com

# Verify ALB health checks are passing (wait ~2 minutes after apply):
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region ap-south-1

# Expected: Both targets showing "healthy" state

# Verify EC2 instances are running:
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names enterprise-3tier-prod-app-asg \
  --region ap-south-1 \
  --query 'AutoScalingGroups[0].Instances[*].{ID:InstanceId,State:LifecycleState,Health:HealthStatus}'

# Verify RDS is available:
aws rds describe-db-instances \
  --db-instance-identifier enterprise-3tier-prod-mysql \
  --region ap-south-1 \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address}'
```

### 🗑️ PHASE 8 — Teardown (When Done Testing)

```bash
# IMPORTANT: If using production environment, disable deletion protection first
# Edit terraform.tfvars:
#   alb_deletion_protection = false
#   db_deletion_protection  = false
terraform apply

# Preview what will be destroyed
terraform plan -destroy

# Destroy all infrastructure resources
terraform destroy

# Type 'yes' when prompted
# Teardown timeline: approximately 8-12 minutes
# Expected: Destroy complete! Resources: 45 destroyed.

# NOTE: The S3 state bucket and DynamoDB table (from bootstrap) are NOT
#       destroyed by 'terraform destroy' on the root module.
#       They are managed separately by the bootstrap module.
#       Leave them running — they cost < $0.01/month.
```

---

## 🔧 Common Operations

```bash
# ─── STATE OPERATIONS ──────────────────────────────────────────────────────

# View human-readable current state
terraform show

# List every resource Terraform manages
terraform state list

# Inspect a specific resource in state
terraform state show module.vpc.aws_vpc.main
terraform state show module.rds.aws_db_instance.main

# Refresh state to match actual AWS reality
terraform refresh

# ─── TARGETED OPERATIONS ───────────────────────────────────────────────────

# Apply changes to a single module only
terraform apply -target=module.vpc
terraform apply -target=module.compute
terraform apply -target=module.rds

# Destroy a single module (careful with dependencies)
terraform destroy -target=module.compute

# ─── DATABASE OPERATIONS ───────────────────────────────────────────────────

# Retrieve database credentials (after apply)
aws secretsmanager get-secret-value \
  --secret-id enterprise-3tier/prod/rds/master-password \
  --region ap-south-1 \
  --query SecretString \
  --output text | python3 -m json.tool

# ─── ZERO-DOWNTIME APPLICATION DEPLOYMENT ──────────────────────────────────

# After updating AMI or instance configuration in terraform.tfvars,
# apply the Launch Template change then trigger instance refresh:

terraform apply -target=module.compute

aws autoscaling start-instance-refresh \
  --auto-scaling-group-name enterprise-3tier-prod-app-asg \
  --preferences '{"MinHealthyPercentage": 50, "InstanceWarmup": 300}' \
  --region ap-south-1

# Monitor refresh progress
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name enterprise-3tier-prod-app-asg \
  --region ap-south-1 \
  --query 'InstanceRefreshes[0].{Status:Status,Percentage:PercentageComplete}'

# ─── SSH ACCESS VIA SSM SESSION MANAGER (no port 22 required) ─────────────

# Install SSM plugin for AWS CLI:
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

# Start session (no key file, no open ports, fully audited)
aws ssm start-session \
  --target $(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names enterprise-3tier-prod-app-asg \
    --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
    --output text --region ap-south-1) \
  --region ap-south-1

# ─── ENVIRONMENT SWITCHING ─────────────────────────────────────────────────

# Switch to development environment
terraform apply -var-file=environments/dev/terraform.tfvars

# Switch to staging environment
terraform apply -var-file=environments/staging/terraform.tfvars

# Switch back to production (default)
terraform apply

# ─── VALIDATION AND FORMATTING ─────────────────────────────────────────────

# Validate all configuration files
terraform validate

# Format all files to canonical style
terraform fmt -recursive

# Check what files would be reformatted (dry run)
terraform fmt -recursive -check

# ─── COST ESTIMATION ───────────────────────────────────────────────────────

# Install Infracost (https://www.infracost.io)
infracost breakdown --path .
```

---

## 🛠️ Technologies Used

<div align="center">

| Technology | Version | Purpose in This Project |
|---|---|---|
| **Terraform** | 1.6+ | Infrastructure as Code engine |
| **AWS Provider** | ~> 5.0 | AWS resource management |
| **Random Provider** | ~> 3.6 | Unique S3 bucket name suffix |
| **AWS VPC** | — | Network isolation and routing |
| **AWS Internet Gateway** | — | Public internet connectivity |
| **AWS NAT Gateway** | — | Private subnet outbound access |
| **AWS ALB** | — | Layer 7 load balancing |
| **AWS EC2** | t2.micro | Application compute instances |
| **AWS Auto Scaling** | — | Automatic capacity management |
| **AWS Launch Template** | — | EC2 instance configuration blueprint |
| **Amazon Linux** | 2023 | EC2 operating system (auto-resolved) |
| **AWS RDS MySQL** | 8.0 | Managed relational database |
| **AWS IAM** | — | Identity and access management |
| **AWS Secrets Manager** | — | Zero-hardcoded credential storage |
| **AWS S3** | — | Terraform remote state storage |
| **AWS DynamoDB** | — | Terraform state distributed locking |
| **AWS CloudWatch** | — | CPU scaling alarms and monitoring |
| **AWS SSM** | — | SSH-free secure instance access |

</div>

---

## 👤 Author

<div align="center">

### Built by a DevOps Engineer — For DevOps Engineers

This project was built from the ground up as a portfolio demonstration
of production-grade AWS infrastructure engineering using Terraform.

Every design decision reflects real enterprise standards:
the security model, the module boundaries, the state management strategy,
the multi-environment approach, and the zero-hardcoded-values philosophy.

<br/>

**Connect & Collaborate**

[![GitHub](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/YOUR-USERNAME)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://linkedin.com/in/YOUR-PROFILE)

<br/>

---

*Zero manual clicks. Zero hardcoded values. Zero compromise.*

**⭐ Star this repository if it helped you level up your Terraform skills! ⭐**

</div>
