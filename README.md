<div align="center">

# 🏦 FinTech Cloud-Native Platform
## Enterprise Infrastructure as Code + GitOps Delivery

<br/>

![Terraform](https://img.shields.io/badge/Terraform-1.6+-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Provider_5.x-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-2.10.4-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Multi--Stage-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Python](https://img.shields.io/badge/FastAPI-0.111.0-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-DevSecOps-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-brightgreen?style=for-the-badge)

<br/>

> ### *"From AWS Infrastructure as Code to containerised GitOps delivery — production engineering patterns, local-first execution."*

<br/>

**Built to reflect 9–15 LPA Platform Engineering maturity.**
**Every design decision mirrors real enterprise delivery workflows.**

<br/>

| 🏗️ Infrastructure | 🔧 Platform | 📦 Application | 🔄 GitOps |
|---|---|---|---|
| AWS Terraform Modules | K3d + ArgoCD | FastAPI Payment Service | App of Apps Pattern |
| VPC · ALB · ASG · RDS | Helm Bootstrap | Multi-Stage Docker | Automated Sync |
| S3 Remote State | NGINX Ingress | Non-Root Security | Self-Healing |

</div>

---

## 📋 Table of Contents

- [What This Project Demonstrates](#-what-this-project-demonstrates)
- [Architecture Overview](#️-architecture-overview)
- [Security Architecture](#-security-architecture)
- [Repository Structure](#-repository-structure)
- [DevSecOps Pipeline](#-devsecops-pipeline)
- [Application — Payment Service](#-application--payment-service)
- [Prerequisites](#️-prerequisites)
- [Quick Start](#-quick-start)
- [Makefile Reference](#-makefile-reference)
- [Environment Strategy](#-environment-strategy)
- [Cost Analysis](#-cost-analysis)
- [Tech Stack](#️-tech-stack)
- [Troubleshooting](#-troubleshooting)
- [Roadmap](#️-roadmap)

---

## 🎯 What This Project Demonstrates

This mono-repo delivers a **complete cloud-native platform engineering stack** — from AWS infrastructure provisioning with Terraform to containerised microservice deployment via GitOps. Built on a local-first philosophy to eliminate cloud experimentation cost while preserving every production operational pattern.

| Skill Domain | What Was Built |
|---|---|
| **Infrastructure as Code** | Modular AWS Terraform — 6 custom modules, S3 remote state, DynamoDB locking, multi-environment tfvars |
| **DevSecOps Pipeline** | GitHub Actions — 5 stages — Trivy IaC scan + TFLint + Validate — zero AWS credentials needed |
| **Container Engineering** | Multi-stage Dockerfile — non-root user, OCI labels, HEALTHCHECK, read-only filesystem |
| **Kubernetes** | K3d local cluster — namespaces, Helm releases, Ingress, liveness + readiness probes |
| **GitOps** | ArgoCD App of Apps — automated sync, selfHeal, prune — Git is single source of truth |
| **Platform Engineering** | Makefile-driven developer workflow — `make restart` restores full platform after reboot |
| **Cloud Security** | IMDSv2, SG-to-SG chain, least-privilege IAM, Secrets Manager, no hardcoded credentials |
| **FinTech Application** | FastAPI payment service — correlation ID middleware, Pydantic validation, structured logging |

---

## 🏛️ Architecture Overview

### The Four Boundaries — Mono-Repo Design

aws-enterprise-3tier-infrastructure-iac/
│
├── infrastructure/   ── AWS Terraform (production cloud foundation)
├── platform/         ── Local K8s bootstrap (Terraform + Helm)
├── applications/     ── FinTech microservice (Docker + Helm chart)
└── gitops/           ── ArgoCD manifests (GitOps delivery layer)

--- 

### AWS 3-Tier Production Infrastructure
┌─────────────────────────────────────────┐
                      │         AWS Cloud — ap-south-1           │
                      │                                          │
Internet ──────────────►│  ┌───────────────────────────────────┐  │
│  │  VPC — 10.0.0.0/16                │  │
│  │                                   │  │
│  │  ┌─── PUBLIC SUBNETS ──────────┐  │  │
│  │  │  AZ-a          AZ-b          │  │  │
│  │  │  10.0.1.0/24  10.0.2.0/24   │  │  │
│  │  │  ┌──────────────────────┐   │  │  │
│  │  │  │  Application Load     │   │  │  │
│  │  │  │  Balancer (80/443)    │   │  │  │
│  │  │  └──────────┬───────────┘   │  │  │
│  │  └─────────────│───────────────┘  │  │
│  │                │ port 80 · SG→SG   │  │
│  │  ┌─── PRIVATE SUBNETS ─────────┐  │  │
│  │  │  AZ-a           AZ-b         │  │  │
│  │  │  10.0.10.0/24  10.0.11.0/24 │  │  │
│  │  │  ┌──────────┐ ┌──────────┐  │  │  │
│  │  │  │EC2+ASG   │ │EC2+ASG   │  │  │  │
│  │  │  │t2.micro  │ │t2.micro  │  │  │  │
│  │  │  │IMDSv2 ✅ │ │IMDSv2 ✅ │  │  │  │
│  │  │  │EBS enc ✅│ │EBS enc ✅│  │  │  │
│  │  │  └──────────┘ └──────────┘  │  │  │
│  │  └─────────────────────────────┘  │  │
│  │                │ port 3306 · SG→SG  │  │
│  │  ┌─── DATABASE SUBNETS ────────┐  │  │
│  │  │  AZ-a            AZ-b        │  │  │
│  │  │  10.0.20.0/24  10.0.21.0/24 │  │  │
│  │  │  ┌──────────────────────┐   │  │  │
│  │  │  │  RDS MySQL 8.0        │   │  │  │
│  │  │  │  db.t3.micro          │   │  │  │
│  │  │  │  AES-256 encrypted ✅ │   │  │  │
│  │  │  │  No internet route ✅ │   │  │  │
│  │  │  └──────────────────────┘   │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
│
┌─────────────────▼───────────────────────┐
│         Terraform Remote State           │
│  S3 Bucket  : enterprise-tfstate-XXXX   │
│  DynamoDB   : state-lock table           │
│  Encryption : AES-256 ✅                 │
│  Versioning : Enabled ✅                 │
└─────────────────────────────────────────┘

---

### Local Platform Architecture — K3d + ArgoCD

Developer Workstation (Ubuntu / WSL2)
│
├── make cluster-up
│     └── K3d cluster: fintech-local
│           ├── k3d-fintech-local-server-0  (control-plane)
│           ├── k3d-fintech-local-agent-0   (worker)
│           └── k3d-fintech-local-agent-1   (worker)
│
├── make platform-bootstrap
│     └── Terraform (kubernetes + helm providers)
│           ├── Namespace: argocd
│           ├── Namespace: platform
│           ├── Namespace: apps
│           ├── Namespace: security
│           ├── Namespace: observability
│           └── ArgoCD v2.10.4 via Helm chart 6.7.3
│
├── make docker-build → make k3d-image-load
│     └── payment-service:1.0.0 loaded into K3d nodes
│
├── kubectl apply -f gitops/argocd-apps/root-app.yaml
│     └── App of Apps bootstrapped
│           └── ArgoCD watches gitops/argocd-apps/
│                 ├── root-app.yaml
│                 └── payment-service-app.yaml
│                       └── Syncs helm-chart from Git
│                             └── payment-service pod Running
│
└── Access Points
├── ArgoCD UI    : http://localhost:8080
├── API Service  : http://localhost:8001
├── API Docs     : http://localhost:8001/docs
└── Health Check : http://localhost:8001/health
---

### GitOps Delivery Flow


 Developer          GitHub Repo          ArgoCD          K3d Cluster
│                   │                  │                 │
│── git push ──────►│                  │                 │
│                   │── detects diff ─►│                 │
│                   │                  │── helm upgrade ►│
│                   │                  │                 │
│                   │                  │◄── Healthy ─────│
│◄─────────────── Synced + Healthy ────────────────────────
│                   │                  │                 │
│  Next change →    │                  │                 │
│── git push ──────►│                  │                 │
│                   │── auto sync ────►│── rolling ─────►│
│                   │                  │   update        │

---


## 🔒 Security Architecture

### 3-Tier Firewall Chain — Principle of Least Privilege

Internet
│
│  ports 80, 443 from 0.0.0.0/0
▼
┌──────────────────────────────────────────┐
│  🔵 ALB Security Group                   │
│  INBOUND  : TCP 80 + 443 from internet   │
│  OUTBOUND : All traffic to VPC           │
└──────────────────┬───────────────────────┘
│  port 80
│  Source = ALB Security Group ID
│  (not CIDR — cannot be spoofed)
▼
┌──────────────────────────────────────────┐
│  🟡 App Security Group (EC2)             │
│  INBOUND  : TCP 80 from ALB SG ID only   │
│  INBOUND  : TCP 22 from VPC CIDR only    │
│  OUTBOUND : All (OS updates via NAT GW)  │
└──────────────────┬───────────────────────┘
│  port 3306
│  Source = App Security Group ID
▼
┌──────────────────────────────────────────┐
│  🔴 DB Security Group (RDS)              │
│  INBOUND  : TCP 3306 from App SG only    │
│  OUTBOUND : VPC CIDR only                │
│  Internet : IMPOSSIBLE                   │
└──────────────────────────────────────────┘

---

### Security Controls Matrix

| Control | Implementation | Standard |
|---|---|---|
| Zero hardcoded credentials | IAM Instance Profile + Secrets Manager | CIS AWS |
| Encryption at rest — EBS | gp3 volumes AES-256 | SOC2 CC6.1 |
| Encryption at rest — RDS | `storage_encrypted = true` | SOC2 CC6.1 |
| Encryption at rest — State | S3 SSE AES-256 + versioning | Internal |
| Encryption in transit — DB | `require_secure_transport = ON` | PCI-DSS 4.1 |
| IMDSv2 enforced | `http_tokens = required` hop limit 1 | CIS AWS 5.6 |
| Least privilege IAM | Scoped ARNs — zero wildcard `*` | ISO 27001 |
| No public database | `publicly_accessible = false` | CIS AWS 2.3 |
| SG-to-SG referencing | Source SG ID not CIDR blocks | AWS Best Practice |
| Auto minor patching | `auto_minor_version_upgrade = true` | CIS AWS 2.2 |
| Non-root containers | `runAsUser: 1001` in all pods | CIS K8s |
| Read-only filesystem | `readOnlyRootFilesystem: true` | CIS K8s |
| Drop all capabilities | `capabilities: drop: [ALL]` | CIS K8s |
| Privilege escalation blocked | `allowPrivilegeEscalation: false` | CIS K8s |

---

## 📁 Repository Structure

aws-enterprise-3tier-infrastructure-iac/         (44+ files · 4 boundaries)
│
├── 📄 Makefile                          ← 15+ operational targets
├── 📄 .gitignore                        ← Excludes state, secrets, plugins
├── 📄 README.md                         ← This file
│
├── 🏗️  infrastructure/                  ← AWS Terraform — 33 files
│   ├── backend.tf                       ← S3 remote state + DynamoDB lock
│   ├── providers.tf                     ← AWS provider + default_tags
│   ├── versions.tf                      ← Pinned: Terraform ~>1.6, AWS ~>5.0
│   ├── main.tf                          ← Root orchestrator — 6 modules
│   ├── variables.tf                     ← Validated inputs with descriptions
│   ├── outputs.tf                       ← Post-apply resource identifiers
│   ├── terraform.tfvars                 ← Production Free Tier values
│   │
│   ├── bootstrap/                       ← One-time S3 + DynamoDB setup
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   │
│   ├── environments/
│   │   ├── dev/terraform.tfvars         ← Dev: no NAT GW · 1 instance
│   │   ├── staging/terraform.tfvars     ← Staging: prod mirror · cost opt
│   │   └── prod/terraform.tfvars        ← Prod: all protections enabled
│   │
│   └── modules/
│       ├── vpc/                         ← VPC · 6 subnets · IGW · NAT · routes
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── security_groups/             ← 3-tier SG chain · SG-to-SG rules
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── alb/                         ← ALB · Target Group · Listener
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── iam/                         ← EC2 role · 4 policies · profile
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── compute/                     ← Launch Template · ASG · CW alarms
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── templates/user_data.sh
│       └── rds/                         ← MySQL 8.0 · Secrets Manager · params
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
├── 🔧  platform/                        ← K8s platform bootstrap
│   ├── versions.tf                      ← Local backend · provider pins
│   ├── providers.tf                     ← Kubernetes + Helm providers
│   ├── variables.tf                     ← Cluster config · ArgoCD version
│   └── main.tf                          ← 5 namespaces + ArgoCD Helm release
│
├── 📦  applications/                    ← FinTech microservice
│   └── payment-service/
│       ├── Dockerfile                   ← Multi-stage · non-root · OCI labels
│       ├── requirements.txt             ← Pinned: fastapi · uvicorn · pydantic
│       ├── app/
│       │   └── main.py                  ← FastAPI · /health · /ready · payments
│       └── helm-chart/
│           ├── Chart.yaml               ← v0.1.0 · appVersion 1.0.0
│           ├── values.yaml              ← K3d-optimised · resource limits
│           └── templates/
│               ├── _helpers.tpl         ← Name and label helpers
│               ├── deployment.yaml      ← SecurityContext · probes · env
│               ├── service.yaml         ← ClusterIP · port 80
│               └── ingress.yaml         ← NGINX · api.fintech.local
│
├── 🔄  gitops/                          ← ArgoCD GitOps manifests
│   ├── argocd-apps/
│   │   ├── root-app.yaml               ← App of Apps root manifest
│   │   └── payment-service-app.yaml    ← Application manifest · auto-sync
│   └── environments/
│       └── local/
│           └── payment-service/
│               └── values.yaml          ← Local environment overrides
│
└── 🔁  .github/
└── workflows/
└── devops-pipeline.yml          ← 5-stage DevSecOps pipeline

---

## 🔁 DevSecOps Pipeline

Every push to `main` triggers the full pipeline — zero AWS credentials required:

git push
│
▼
Stage 1 ── Secure Checkout & Cache ──────────────────── ✅
Provider plugin caching (40-60% faster runs)
Repository structure audit
Concurrency control (cancel stale runs)
│
├──────────────────────────────────┐
▼                                  ▼
Stage 2 ── Terraform Format ── ✅    Stage 3 ── Trivy Scan ────── ✅
terraform fmt                       Misconfig detection
-check -recursive                   Secret scanning
Canonical HCL                       SARIF → GitHub Security
enforcement                         CIS AWS benchmark checks
│
▼
Stage 4 ── TFLint Analysis ──────────────────────────── ✅
AWS ruleset plugin
8 modules scanned
infrastructure/ + platform/
Invalid resource detection
│
▼
Stage 5 ── Terraform Validate ───────────────────────── ✅
-backend=false (no S3 needed)
infrastructure/ root module
All 6 child modules individually
platform/ boundary
PR comment with per-module results

---

## 📦 Application — FinTech Payment Service

### What It Does

A cloud-native REST API simulating a FinTech payment processing service. Demonstrates production API patterns — structured responses, correlation ID tracing, Pydantic validation, and Kubernetes-native health probes.

### API Endpoints

| Method | Path | Purpose | K8s Probe |
|---|---|---|---|
| GET | `/health` | Liveness check | `livenessProbe` |
| GET | `/ready` | Readiness check | `readinessProbe` |
| GET | `/` | Service discovery | — |
| GET | `/docs` | OpenAPI interactive docs | — |
| POST | `/api/v1/payments` | Process payment | — |
| GET | `/api/v1/payments/{id}` | Payment status | — |

### Access Your Application

```bash
# Start port-forward
kubectl port-forward svc/payment-service 8001:80 -n apps &
sleep 3

# Health check
curl -s http://localhost:8001/health | python3 -m json.tool

# Process a payment
curl -s -X POST http://localhost:8001/api/v1/payments \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: demo-$(date +%s)" \
  -d '{
    "transaction_id": "TXN-DEMO-001",
    "amount": 10000.00,
    "currency": "INR",
    "sender_account": "ACC-GOVIND-001",
    "receiver_account": "ACC-CLIENT-002"
  }' | python3 -m json.tool

# Open interactive API docs in browser
echo "Open → http://localhost:8001/docs"

# ArgoCD GitOps dashboard
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
echo "Open → http://localhost:8080  |  Username: admin"
```

### Docker Security Features

```dockerfile
# Multi-stage: builder → runtime
# Dependencies never leave builder stage

# Non-root user — mandatory enterprise standard
RUN useradd --uid 1001 --gid appgroup appuser
USER appuser

# OCI standard labels
LABEL org.opencontainers.image.version="${APP_VERSION}"
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"

# Docker-native health check
HEALTHCHECK --interval=30s --timeout=10s CMD ...
```

---

## ⚙️ Prerequisites

```bash
# All tools required — verify before starting
docker    --version    # 20.x+  — container runtime
k3d       version      # 5.x+   — local Kubernetes
kubectl   version      # 1.28+  — cluster CLI
terraform version      # 1.6+   — infrastructure as code
helm      version      # 3.x+   — Kubernetes package manager
make      --version    # 4.x+   — workflow automation

# Install missing tools
make deps              # checks and shows install commands
```

---

## 🚀 Quick Start

### First Time Setup

```bash
# 1. Clone
git clone https://github.com/govinddevops/aws-enterprise-3tier-infrastructure-iac.git
cd aws-enterprise-3tier-infrastructure-iac

# 2. Verify tools
make deps

# 3. Create K3d cluster (1 server + 2 agents · K3s v1.28.8)
make cluster-up

# 4. Verify cluster healthy
make cluster-status

# 5. Bootstrap platform — namespaces + ArgoCD
make platform-init
make platform-bootstrap

# 6. Build and load application image
make docker-build
make k3d-image-load

# 7. Install NGINX Ingress Controller
make nginx-install

# 8. Add local DNS
make hosts-setup

# 9. Deploy payment-service
make app-deploy

# 10. Bootstrap GitOps — one manual step
kubectl apply -f gitops/argocd-apps/root-app.yaml

# 11. Access ArgoCD
make argocd-password
make argocd-open
# Browser → http://localhost:8080 · username: admin

# 12. Access application
kubectl port-forward svc/payment-service 8001:80 -n apps &
# Browser → http://localhost:8001/docs
```

### After PC Reboot

```bash
# Single command — restores everything
make restart
```

### Verify Everything Running

```bash
make cluster-status     # All 3 nodes Ready
make app-status         # payment-service 1/1 Running
kubectl get applications -n argocd   # Synced + Healthy
```

---

## 🔧 Makefile Reference

| Target | What It Does |
|---|---|
| `make deps` | Check all required tools installed |
| `make cluster-up` | Create K3d 3-node cluster |
| `make cluster-status` | Show nodes + system pods + namespaces |
| `make cluster-down` | Delete K3d cluster |
| `make platform-init` | `terraform init` for platform/ |
| `make platform-plan` | Preview platform changes |
| `make platform-bootstrap` | Deploy namespaces + ArgoCD to cluster |
| `make docker-build` | Build multi-stage Docker image |
| `make docker-run` | Run container locally on port 8000 |
| `make k3d-image-load` | Import image into K3d nodes |
| `make nginx-install` | Install NGINX Ingress Controller |
| `make hosts-setup` | Add local DNS to /etc/hosts |
| `make app-deploy` | Helm install to apps namespace |
| `make app-status` | Show pods + services + ingress |
| `make app-logs` | Stream pod logs live |
| `make app-test` | Test API endpoints via port-forward |
| `make app-delete` | Helm uninstall payment-service |
| `make argocd-password` | Get ArgoCD admin initial password |
| `make argocd-open` | Port-forward ArgoCD UI to :8080 |
| `make restart` | **Full restore after PC reboot** |
| `make destroy` | Destroy platform Terraform resources |
| `make clean` | Full teardown — platform + cluster |

---

## 🌍 Multi-Environment Strategy

| Configuration | Dev | Staging | Production |
|---|---|---|---|
| VPC CIDR | 10.1.0.0/16 | 10.2.0.0/16 | 10.0.0.0/16 |
| EC2 Instances | 1 (desired) | 2 (desired) | 2 (desired) |
| NAT Gateway | ❌ Disabled | ✅ Enabled | ✅ Enabled |
| Multi-AZ RDS | ❌ No | ❌ Cost opt | ❌ Cost opt |
| Deletion Protection | ❌ Off | ✅ On | ✅ On |
| Final Snapshot | ❌ Skip | ✅ Take | ✅ Take |
| Backup Retention | 1 day | 7 days | 7 days |
| Scale-Out CPU | 60% | 60% | 70% |
| Monthly Cost | ~$16 | ~$48 | ~$48 |

```bash
# Target specific environment
terraform apply -var-file=infrastructure/environments/dev/terraform.tfvars
terraform apply -var-file=infrastructure/environments/staging/terraform.tfvars
terraform apply   # defaults to prod
```

---

## 💰 Cost Analysis

| Resource | Type | Free Tier | Est. Monthly |
|---|---|---|---|
| EC2 Application Servers × 2 | t2.micro | ✅ 750 hrs/month | $0 first 12 months |
| RDS Database × 1 | db.t3.micro | ✅ 750 hrs/month | $0 first 12 months |
| EBS Root Volumes × 2 | gp3 15 GiB each | ✅ 30 GiB/month | $0 first 12 months |
| Application Load Balancer | ALB | ❌ Not Free Tier | ~$16/month |
| NAT Gateway × 1 | Shared | ❌ Not Free Tier | ~$32/month |
| S3 State Bucket | — | ✅ 5 GB free | ~$0.01/month |
| DynamoDB Lock Table | PAY_PER_REQUEST | ✅ 25 GB free | $0 |
| Secrets Manager | 1 secret | — | ~$0.40/month |
| K3d Local Cluster | Laptop | ✅ Free | $0 |
| **Total** | | | **~$48/month** |

> **Destroy when not testing:** `make clean` removes all billable AWS resources instantly.

---

## 🛠️ Tech Stack

| Layer | Technology | Version | Purpose |
|---|---|---|---|
| Infrastructure as Code | Terraform | 1.6+ | AWS resource provisioning |
| Cloud Provider | AWS | Provider ~>5.0 | VPC · ALB · ASG · RDS · IAM · S3 |
| State Backend | S3 + DynamoDB | — | Remote state + distributed locking |
| Container Runtime | Docker | 29.x | Multi-stage image builds |
| Local Kubernetes | K3d (K3s) | 1.28 | Cluster simulation on laptop |
| Package Manager | Helm | 3.x | Kubernetes app delivery |
| GitOps Controller | ArgoCD | 2.10.4 | Automated sync from Git |
| Ingress Controller | NGINX | latest | HTTP routing and load balancing |
| App Framework | FastAPI | 0.111.0 | Payment service REST API |
| App Server | Uvicorn | 0.30.1 | Production ASGI server |
| Data Validation | Pydantic | 2.7.1 | Request/response models |
| Language Runtime | Python | 3.11 | Application container |
| Terraform Linter | TFLint | 0.50.3 | AWS ruleset quality gates |
| Security Scanner | Trivy (Aqua) | latest | IaC misconfig + secret scan |
| CI/CD | GitHub Actions | — | 5-stage DevSecOps pipeline |
| Workflow Automation | GNU Make | 4.x | Developer experience layer |

---

## 🔍 Troubleshooting

| Symptom | Root Cause | Fix |
|---|---|---|
| `cluster not accessible` | K3d stopped after PC reboot | `make restart` |
| `EXTERNAL-IP: <pending>` | WSL LoadBalancer limitation | Normal — use `kubectl port-forward` |
| `context deadline exceeded` | Helm `--wait` on WSL networking | Pod is running — ignore Helm timeout |
| `apiVersion not set` | Helm template function mismatch | `helm template` dry-run first |
| `webhook certificate error` | Stale validating webhook in cluster | `kubectl delete validatingwebhookconfiguration ingress-nginx-admission` |
| `ArgoCD CRD not found` | ArgoCD not deployed | `make platform-bootstrap` |
| `No resources in argocd ns` | Platform needs re-bootstrap | `make platform-bootstrap` |
| Pipeline Stage 2 fails | Terraform fmt violations | `terraform fmt -recursive` then push |
| Pipeline Stage 5 fails | Wrong `-chdir` paths | Paths should start with `infrastructure/` |
| `Could not resolve host` | WSL DNS for .local domains | Use `kubectl port-forward` instead |
| Agent node NotReady | containerd socket after WSL sleep | `docker restart k3d-fintech-local-agent-0` |

---

## 🗺️ Roadmap

Phase 1   K3d Cluster + ArgoCD Bootstrap          ✅ Complete
Phase 2   Containerised FinTech Payment Service   ✅ Complete
Phase 3   GitOps with ArgoCD App of Apps          ✅ Complete

       ──────────────────────────────────────────────────────────────
Phase 4   Observability Stack                     ⬜ Planned
kube-prometheus-stack
Grafana dashboards (ArgoCD + app metrics)
Loki log aggregation
Phase 5   EKS Cloud Migration                     ⬜ Planned
Move from K3d to AWS EKS
ALB Ingress Controller
IRSA for pod-level IAM
Phase 6   Service Mesh                            ⬜ Planned
Istio for mTLS between services
Traffic management + circuit breaking

---

<div align="center">

## 👤 About This Project

**Govind — DevOps and Platform Engineering**

Built with experience from:
- **Ezdat Technology** — 1 Year DevOps Internship (startup engineering pace)
- **Yamaha, Noida** — Industrial DevOps Training (corporate delivery standards)

This project bridges startup engineering speed with
corporate delivery discipline — every pattern here
is production-ready and interview-proven.

<br/>

[![GitHub](https://img.shields.io/badge/GitHub-govinddevops-100000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/govinddevops)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://linkedin.com/in/your-profile)

<br/>

---

*Zero manual clicks. Zero hardcoded values. Zero compromise on security.*

**⭐ If this project helped you — please star the repository ⭐**

</div>


























