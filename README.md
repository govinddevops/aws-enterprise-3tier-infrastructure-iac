<div align="center">

# 🏦 FinTech Cloud-Native Platform

### Enterprise Infrastructure as Code + GitOps Delivery

[![Terraform](https://img.shields.io/badge/Terraform-1.6+-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Provider_5.x-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)](https://aws.amazon.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-2.10.4-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)
[![Docker](https://img.shields.io/badge/Docker-Multi--Stage-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.111.0-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-DevSecOps-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![License](https://img.shields.io/badge/License-MIT-brightgreen?style=for-the-badge)](LICENSE)

> **From AWS Infrastructure as Code to containerised GitOps delivery.**
> Production engineering patterns. Local-first execution. Zero cloud waste.

**Built to reflect 9–15 LPA Platform Engineering maturity.**

</div>

---

## 📋 Table of Contents

- [What This Project Demonstrates](#-what-this-project-demonstrates)
- [Architecture Overview](#️-architecture-overview)
- [Security Architecture](#-security-architecture)
- [Repository Structure](#-repository-structure)
- [DevSecOps Pipeline](#-devsecops-pipeline)
- [Application — Payment Service](#-application--fintech-payment-service)
- [Prerequisites](#️-prerequisites)
- [Quick Start](#-quick-start)
- [Makefile Reference](#-makefile-reference)
- [Multi-Environment Strategy](#-multi-environment-strategy)
- [Cost Analysis](#-cost-analysis)
- [Tech Stack](#️-tech-stack)
- [Troubleshooting](#-troubleshooting)
- [Roadmap](#️-roadmap)

---

## 🎯 What This Project Demonstrates

A complete **cloud-native platform engineering stack** — from AWS infrastructure provisioning with Terraform to containerised microservice delivery via GitOps. Built local-first to eliminate cloud experimentation cost while preserving every production operational pattern.

| Skill Domain | What Was Built |
|---|---|
| **Infrastructure as Code** | Modular AWS Terraform — 6 custom modules, S3 remote state, DynamoDB locking, multi-environment tfvars |
| **DevSecOps Pipeline** | GitHub Actions — 5 stages — Trivy IaC scan + TFLint + Validate — zero AWS credentials needed |
| **Container Engineering** | Multi-stage Dockerfile — non-root user `uid=1001`, OCI labels, HEALTHCHECK, read-only filesystem |
| **Kubernetes** | K3d local cluster — namespaces, Helm releases, NGINX Ingress, liveness + readiness probes |
| **GitOps** | ArgoCD App of Apps — automated sync, selfHeal, prune — Git is single source of truth |
| **Platform Engineering** | Makefile-driven developer workflow — `make restart` restores full platform after reboot |
| **Cloud Security** | IMDSv2, SG-to-SG chain, least-privilege IAM, Secrets Manager, no hardcoded credentials |
| **FinTech Application** | FastAPI payment service — correlation ID middleware, Pydantic validation, structured JSON logging |

---

## 🏛️ Architecture Overview

### The Four Boundaries — Mono-Repo Design

| Boundary | Path | Purpose |
|---|---|---|
| 🏗️ Infrastructure | `infrastructure/` | AWS Terraform — production cloud foundation |
| 🔧 Platform | `platform/` | Local K8s bootstrap via Terraform + Helm |
| 📦 Application | `applications/` | FinTech microservice — Docker + Helm chart |
| 🔄 GitOps | `gitops/` | ArgoCD manifests — automated delivery layer |

---

### AWS 3-Tier Production Infrastructure

```mermaid
graph TD
    Internet([🌐 Internet]) --> IGW[Internet Gateway]
    IGW --> ALB

    subgraph VPC["VPC — 10.0.0.0/16 — ap-south-1"]
        subgraph PUBLIC["PUBLIC SUBNETS"]
            PUB_A["AZ-a 10.0.1.0/24"]
            PUB_B["AZ-b 10.0.2.0/24"]
            ALB["⚖️ Application Load Balancer\nports 80 / 443"]
        end

        subgraph PRIVATE["PRIVATE SUBNETS"]
            PRIV_A["AZ-a 10.0.10.0/24"]
            PRIV_B["AZ-b 10.0.11.0/24"]
            EC2_A["EC2 + ASG\nt2.micro\nIMDSv2 ✅\nEBS encrypted ✅"]
            EC2_B["EC2 + ASG\nt2.micro\nIMDSv2 ✅\nEBS encrypted ✅"]
        end

        subgraph DATABASE["DATABASE SUBNETS"]
            DB_A["AZ-a 10.0.20.0/24"]
            DB_B["AZ-b 10.0.21.0/24"]
            RDS["🗄️ RDS MySQL 8.0\ndb.t3.micro\nAES-256 encrypted ✅\nNo internet route ✅"]
        end

        subgraph STATE["Terraform Remote State"]
            S3["S3 Bucket\nenterprise-tfstate-XXXX\nAES-256 + Versioning"]
            DDB["DynamoDB\nState Lock Table"]
        end
    end

    ALB -->|"port 80 · SG→SG"| EC2_A
    ALB -->|"port 80 · SG→SG"| EC2_B
    EC2_A -->|"port 3306 · SG→SG"| RDS
    EC2_B -->|"port 3306 · SG→SG"| RDS
    NAT["NAT Gateway\nElastic IP"] --> Internet
    EC2_A --> NAT
    EC2_B --> NAT
```

---

### Local Platform Architecture — K3d + ArgoCD

```mermaid
graph TD
    DEV["👨‍💻 Developer\nUbuntu / WSL2"] --> MK["make cluster-up"]

    MK --> K3D["K3d Cluster: fintech-local\nK3s v1.28.8"]
    K3D --> SRV["server-0\ncontrol-plane"]
    K3D --> AG0["agent-0\nworker"]
    K3D --> AG1["agent-1\nworker"]

    K3D --> BOOTSTRAP["make platform-bootstrap\nTerraform: kubernetes + helm providers"]
    BOOTSTRAP --> NS_ARGOCD["Namespace: argocd"]
    BOOTSTRAP --> NS_PLATFORM["Namespace: platform"]
    BOOTSTRAP --> NS_APPS["Namespace: apps"]
    BOOTSTRAP --> NS_SEC["Namespace: security"]
    BOOTSTRAP --> NS_OBS["Namespace: observability"]
    BOOTSTRAP --> ARGOCD["ArgoCD v2.10.4\nHelm chart 6.7.3"]

    DEV --> DOCKER["make docker-build\npayment-service:1.0.0"]
    DOCKER --> LOAD["make k3d-image-load"]
    LOAD --> K3D

    DEV --> ROOTAPP["kubectl apply\ngitops/argocd-apps/root-app.yaml"]
    ROOTAPP --> ARGOCD
    ARGOCD --> WATCH["Watches gitops/argocd-apps/"]
    WATCH --> PS_APP["payment-service-app.yaml\nauto-sync enabled"]
    PS_APP --> HELM["Helm chart sync from Git"]
    HELM --> POD["payment-service pod\n1/1 Running ✅"]

    POD --> ACCESS["Access Points"]
    ACCESS --> UI["ArgoCD UI\nlocalhost:8080"]
    ACCESS --> API["API Service\nlocalhost:8001"]
    ACCESS --> DOCS["API Docs\nlocalhost:8001/docs"]
```

---

### GitOps Delivery Flow

```mermaid
sequenceDiagram
    participant Dev as 👨‍💻 Developer
    participant Git as 📁 GitHub Repo
    participant Argo as 🔄 ArgoCD
    participant K3d as ☸️ K3d Cluster

    Dev->>Git: git push (code change)
    Git-->>Argo: webhook / poll (every 3min)
    Argo->>Git: detect diff (desired vs actual)
    Argo->>K3d: helm upgrade (rolling update)
    K3d-->>Argo: Healthy ✅
    Argo-->>Dev: Synced + Healthy

    Note over Dev,K3d: Next change
    Dev->>Git: git push (image tag update)
    Argo->>Git: detect new tag
    Argo->>K3d: rolling pod replacement
    K3d-->>Argo: 0 downtime ✅
```

---

## 🔒 Security Architecture

### 3-Tier Firewall Chain — Principle of Least Privilege

```mermaid
graph TD
    INTERNET([🌐 Internet]) -->|"TCP 80, 443"| ALB_SG

    subgraph ALB_SG["🔵 ALB Security Group"]
        ALB_IN["INBOUND: TCP 80 + 443 from 0.0.0.0/0"]
        ALB_OUT["OUTBOUND: All traffic to VPC"]
    end

    ALB_SG -->|"port 80 · Source = ALB SG ID\nnot CIDR — cannot be spoofed"| APP_SG

    subgraph APP_SG["🟡 App Security Group — EC2"]
        APP_IN1["INBOUND: TCP 80 from ALB SG ID only"]
        APP_IN2["INBOUND: TCP 22 from VPC CIDR only"]
        APP_OUT["OUTBOUND: All — OS updates via NAT GW"]
    end

    APP_SG -->|"port 3306 · Source = App SG ID"| DB_SG

    subgraph DB_SG["🔴 DB Security Group — RDS"]
        DB_IN["INBOUND: TCP 3306 from App SG only"]
        DB_OUT["OUTBOUND: VPC CIDR only"]
        DB_BLOCK["INTERNET: IMPOSSIBLE ❌"]
    end
```

### Security Controls Matrix

| Control | Implementation | Standard |
|---|---|---|
| Zero hardcoded credentials | IAM Instance Profile + Secrets Manager | CIS AWS |
| Encryption at rest — EBS | `gp3` volumes AES-256 | SOC2 CC6.1 |
| Encryption at rest — RDS | `storage_encrypted = true` | SOC2 CC6.1 |
| Encryption at rest — State | S3 SSE AES-256 + versioning enabled | Internal |
| Encryption in transit — DB | `require_secure_transport = ON` | PCI-DSS 4.1 |
| IMDSv2 enforced | `http_tokens = required` — hop limit 1 | CIS AWS 5.6 |
| Least privilege IAM | Scoped ARNs — zero wildcard `*` | ISO 27001 |
| No public database | `publicly_accessible = false` | CIS AWS 2.3 |
| SG-to-SG referencing | Source SG ID — not CIDR blocks | AWS Best Practice |
| Auto minor patching | `auto_minor_version_upgrade = true` | CIS AWS 2.2 |
| Non-root containers | `runAsUser: 1001` in all pods | CIS K8s |
| Read-only filesystem | `readOnlyRootFilesystem: true` | CIS K8s |
| Drop all capabilities | `capabilities: drop: [ALL]` | CIS K8s |
| Privilege escalation blocked | `allowPrivilegeEscalation: false` | CIS K8s |

---

## 📁 Repository Structure

| Path | Description |
|---|---|
| `Makefile` | 15+ operational targets — full developer workflow |
| `.gitignore` | Excludes state files, secrets, `.terraform/` plugins |
| `README.md` | This file |
| **`infrastructure/`** | **AWS Terraform — 33 files** |
| `infrastructure/backend.tf` | S3 remote state + DynamoDB lock |
| `infrastructure/providers.tf` | AWS provider + `default_tags` on every resource |
| `infrastructure/versions.tf` | Pinned: Terraform `~>1.6`, AWS provider `~>5.0` |
| `infrastructure/main.tf` | Root orchestrator — calls all 6 modules |
| `infrastructure/variables.tf` | Validated inputs with descriptions |
| `infrastructure/outputs.tf` | Post-apply resource identifiers |
| `infrastructure/terraform.tfvars` | Production Free Tier values |
| `infrastructure/bootstrap/` | One-time S3 + DynamoDB setup |
| `infrastructure/environments/dev/` | Dev: no NAT GW · 1 instance · no protection |
| `infrastructure/environments/staging/` | Staging: prod mirror · cost optimised |
| `infrastructure/environments/prod/` | Prod: all protections enabled |
| `infrastructure/modules/vpc/` | VPC · 6 subnets · IGW · NAT · route tables |
| `infrastructure/modules/security_groups/` | 3-tier SG chain · SG-to-SG rules |
| `infrastructure/modules/alb/` | ALB · Target Group · HTTP Listener |
| `infrastructure/modules/iam/` | EC2 role · 4 policies · instance profile |
| `infrastructure/modules/compute/` | Launch Template · ASG · CloudWatch alarms |
| `infrastructure/modules/rds/` | MySQL 8.0 · Secrets Manager · parameter group |
| **`platform/`** | **K8s platform bootstrap** |
| `platform/versions.tf` | Local backend · provider version pins |
| `platform/providers.tf` | Kubernetes + Helm providers via kubeconfig |
| `platform/variables.tf` | Cluster config · ArgoCD chart version |
| `platform/main.tf` | 5 namespaces + ArgoCD Helm release |
| **`applications/payment-service/`** | **FinTech microservice** |
| `Dockerfile` | Multi-stage · non-root uid=1001 · OCI labels |
| `requirements.txt` | Pinned: fastapi · uvicorn · pydantic · httpx |
| `app/main.py` | FastAPI · `/health` · `/ready` · `/api/v1/payments` |
| `helm-chart/Chart.yaml` | Chart v0.1.0 · appVersion 1.0.0 |
| `helm-chart/values.yaml` | K3d-optimised · resource limits · probes |
| `helm-chart/templates/deployment.yaml` | SecurityContext · probes · env vars |
| `helm-chart/templates/service.yaml` | ClusterIP · port 80 → targetPort 8000 |
| `helm-chart/templates/ingress.yaml` | NGINX · host: `api.fintech.local` |
| **`gitops/`** | **ArgoCD GitOps manifests** |
| `gitops/argocd-apps/root-app.yaml` | App of Apps root manifest |
| `gitops/argocd-apps/payment-service-app.yaml` | Application manifest · auto-sync |
| `gitops/environments/local/payment-service/values.yaml` | Local environment overrides |
| **`.github/workflows/`** | **CI/CD Pipeline** |
| `devops-pipeline.yml` | 5-stage DevSecOps pipeline |

---

## 🔁 DevSecOps Pipeline

Every push to `main` triggers the full pipeline — **zero AWS credentials required.**

```mermaid
graph LR
    PUSH["git push\nto main"] --> S1

    S1["📦 Stage 1\nCheckout & Cache\n✅"]
    S1 --> S2
    S1 --> S3

    S2["🎨 Stage 2\nTerraform fmt\n-check -recursive\n✅"]
    S3["🔐 Stage 3\nAqua Trivy\nIaC misconfig\nSecret scan\nSARIF upload\n✅"]

    S2 --> S4
    S3 --> S4

    S4["🔍 Stage 4\nTFLint\nAWS ruleset\n8 modules\n✅"]
    S4 --> S5

    S5["✅ Stage 5\nTerraform Validate\n-backend=false\ninfrastructure/ root\n6 child modules\nplatform/ boundary\n✅"]
```

| Stage | Tool | What It Checks |
|---|---|---|
| Stage 1 | `actions/checkout@v4` | Secure fetch · provider cache · concurrency control |
| Stage 2 | `terraform fmt` | Canonical HCL formatting — fails on any diff |
| Stage 3 | Aqua Security Trivy | IaC misconfigs · hardcoded secrets · CIS AWS benchmarks |
| Stage 4 | TFLint + AWS ruleset | Invalid resources · deprecated APIs · naming conventions |
| Stage 5 | `terraform validate` | Module structure · variable types · resource arguments |

---

## 📦 Application — FinTech Payment Service

A cloud-native REST API simulating a FinTech payment processing service. Demonstrates production API patterns — structured JSON responses, X-Correlation-ID distributed tracing, Pydantic request validation, and Kubernetes-native health probes.

### API Endpoints

| Method | Path | Purpose | K8s Probe |
|---|---|---|---|
| `GET` | `/health` | Liveness check — fast, no DB calls | `livenessProbe` |
| `GET` | `/ready` | Readiness check — service ready to serve | `readinessProbe` |
| `GET` | `/` | Service discovery — lists all endpoints | — |
| `GET` | `/docs` | OpenAPI interactive documentation | — |
| `POST` | `/api/v1/payments` | Process payment transaction | — |
| `GET` | `/api/v1/payments/{id}` | Payment status lookup | — |

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

# Interactive API docs — open in browser
echo "→ http://localhost:8001/docs"

# ArgoCD GitOps dashboard
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
make argocd-password
echo "→ http://localhost:8080  |  username: admin"
```

### Container Security Features

- **Multi-stage build** — dependencies isolated in builder stage, never in runtime
- **Non-root user** — `useradd --uid 1001 appgroup` — process never runs as root
- **OCI standard labels** — `org.opencontainers.image.version`, `revision`, `created`
- **HEALTHCHECK** — Docker-native health monitoring independent of Kubernetes
- **Explicit COPY** — no `COPY . .` — prevents `.env` files or secrets leaking in
- **Pinned base image** — `python:3.11-slim` — no floating `latest` tag

---

## ⚙️ Prerequisites

```bash
docker    --version    # 20.x+  — container runtime
k3d       version      # 5.x+   — local Kubernetes clusters
kubectl   version      # 1.28+  — cluster management CLI
terraform version      # 1.6+   — infrastructure as code
helm      version      # 3.x+   — Kubernetes package manager
make      --version    # 4.x+   — workflow automation

# Check everything at once
make deps
```

---

## 🚀 Quick Start

### First Time Setup

```bash
# 1. Clone repository
git clone https://github.com/govinddevops/aws-enterprise-3tier-infrastructure-iac.git
cd aws-enterprise-3tier-infrastructure-iac

# 2. Check all tools installed
make deps

# 3. Create K3d cluster — 1 server + 2 agents — K3s v1.28.8
make cluster-up

# 4. Verify cluster healthy
make cluster-status

# 5. Bootstrap platform — namespaces + ArgoCD
make platform-init
make platform-bootstrap

# 6. Build Docker image and load into K3d
make docker-build
make k3d-image-load

# 7. Install NGINX Ingress Controller
make nginx-install

# 8. Add local DNS entries to /etc/hosts
make hosts-setup

# 9. Deploy payment-service via Helm
make app-deploy

# 10. Bootstrap GitOps — one manual step only
kubectl apply -f gitops/argocd-apps/root-app.yaml

# 11. Open ArgoCD dashboard
make argocd-password
make argocd-open
# → http://localhost:8080  |  username: admin

# 12. Access payment service API
kubectl port-forward svc/payment-service 8001:80 -n apps &
# → http://localhost:8001/docs
```

### After PC Reboot

```bash
# Single command — restores complete platform state
make restart
```

### Verify Everything

```bash
make cluster-status                    # 3 nodes Ready
make app-status                        # payment-service 1/1 Running
kubectl get applications -n argocd     # Synced + Healthy
```

---

## 🔧 Makefile Reference

| Target | Description |
|---|---|
| `make deps` | Verify all required tools are installed |
| `make cluster-up` | Create K3d 3-node cluster |
| `make cluster-status` | Show nodes + system pods + namespaces |
| `make cluster-down` | Delete K3d cluster |
| `make platform-init` | `terraform init` for platform/ |
| `make platform-plan` | Preview platform Terraform changes |
| `make platform-bootstrap` | Deploy namespaces + ArgoCD to cluster |
| `make docker-build` | Build multi-stage Docker image |
| `make docker-run` | Run container locally on port 8000 |
| `make k3d-image-load` | Import Docker image into K3d nodes |
| `make nginx-install` | Install NGINX Ingress Controller via Helm |
| `make hosts-setup` | Add `api.fintech.local` to `/etc/hosts` |
| `make app-deploy` | Helm install payment-service to apps namespace |
| `make app-status` | Show pods + services + ingress |
| `make app-logs` | Stream pod logs live |
| `make app-test` | Test API endpoints via port-forward |
| `make app-delete` | Helm uninstall payment-service |
| `make argocd-password` | Get ArgoCD admin initial password |
| `make argocd-open` | Port-forward ArgoCD UI to `:8080` |
| **`make restart`** | **Full platform restore after PC reboot** |
| `make destroy` | Destroy platform Terraform resources |
| `make clean` | Full teardown — platform + cluster |

---

## 🌍 Multi-Environment Strategy

| Configuration | Dev | Staging | Production |
|---|---|---|---|
| VPC CIDR | `10.1.0.0/16` | `10.2.0.0/16` | `10.0.0.0/16` |
| EC2 Instances | 1 desired | 2 desired | 2 desired |
| NAT Gateway | ❌ Disabled | ✅ Enabled | ✅ Enabled |
| Multi-AZ RDS | ❌ No | ❌ Cost opt | ❌ Cost opt |
| Deletion Protection | ❌ Off | ✅ On | ✅ On |
| Final DB Snapshot | ❌ Skip | ✅ Take | ✅ Take |
| Backup Retention | 1 day | 7 days | 7 days |
| Scale-Out CPU | 60% | 60% | 70% |
| Est. Monthly Cost | ~$16 | ~$48 | ~$48 |

```bash
# Target specific environment
terraform -chdir=infrastructure apply \
  -var-file=environments/dev/terraform.tfvars

terraform -chdir=infrastructure apply \
  -var-file=environments/staging/terraform.tfvars

# Production (default terraform.tfvars)
terraform -chdir=infrastructure apply
```

---

## 💰 Cost Analysis

| Resource | Type | Free Tier | Est. Monthly |
|---|---|---|---|
| EC2 Application Servers × 2 | `t2.micro` | ✅ 750 hrs/month | $0 *(first 12 months)* |
| RDS Database × 1 | `db.t3.micro` | ✅ 750 hrs/month | $0 *(first 12 months)* |
| EBS Root Volumes × 2 | `gp3` 15 GiB each | ✅ 30 GiB/month | $0 *(first 12 months)* |
| Application Load Balancer | ALB | ❌ Not Free Tier | ~$16/month |
| NAT Gateway × 1 | Shared single | ❌ Not Free Tier | ~$32/month |
| S3 State Bucket | Storage + requests | ✅ 5 GB free | ~$0.01/month |
| DynamoDB Lock Table | `PAY_PER_REQUEST` | ✅ 25 GB free | $0 |
| Secrets Manager | 1 secret | — | ~$0.40/month |
| K3d Local Cluster | Runs on laptop | ✅ Free | $0 |
| **Total** | | | **~$48/month** |

> ⚠️ Run `make clean` when not testing — removes all billable AWS resources instantly.

---

## 🛠️ Tech Stack

| Layer | Technology | Version | Purpose |
|---|---|---|---|
| Infrastructure as Code | Terraform | `~> 1.6` | AWS resource provisioning |
| Cloud Provider | AWS | Provider `~> 5.0` | VPC · ALB · ASG · RDS · IAM · S3 |
| State Backend | S3 + DynamoDB | — | Remote state + distributed locking |
| Container Runtime | Docker | `29.x` | Multi-stage image builds |
| Local Kubernetes | K3d (K3s) | `v1.28.8` | Cluster simulation on laptop |
| Package Manager | Helm | `3.x` | Kubernetes application delivery |
| GitOps Controller | ArgoCD | `2.10.4` | Automated sync from Git |
| Ingress Controller | NGINX | latest | HTTP routing and load balancing |
| App Framework | FastAPI | `0.111.0` | Payment service REST API |
| App Server | Uvicorn | `0.30.1` | Production ASGI server |
| Data Validation | Pydantic | `2.7.1` | Request / response models |
| Language Runtime | Python | `3.11-slim` | Application container base |
| IaC Linter | TFLint | `v0.50.3` | AWS ruleset quality gates |
| Security Scanner | Trivy (Aqua) | latest | IaC misconfig + secret detection |
| CI/CD | GitHub Actions | — | 5-stage DevSecOps pipeline |
| Workflow Automation | GNU Make | `4.x` | Developer experience layer |

---

## 🔍 Troubleshooting

| Symptom | Root Cause | Fix |
|---|---|---|
| `cluster not accessible` | K3d stopped after PC reboot | `make restart` |
| `EXTERNAL-IP: <pending>` | WSL LoadBalancer limitation — expected | Normal — use `kubectl port-forward` |
| `context deadline exceeded` | Helm `--wait` hangs on WSL networking | Pod is running — Helm timeout is cosmetic |
| `apiVersion not set` | Helm template function mismatch | Run `helm template` dry-run to debug |
| `webhook certificate error` | Stale validating webhook in cluster | `kubectl delete validatingwebhookconfiguration ingress-nginx-admission` |
| `ArgoCD CRD not found` | ArgoCD not deployed yet | `make platform-bootstrap` |
| `No resources in argocd ns` | Platform reset after reboot | `make platform-bootstrap` |
| Pipeline Stage 2 fails | Terraform fmt violations | `terraform fmt -recursive` then push |
| Pipeline Stage 5 fails | Wrong `-chdir` paths | Paths must start with `infrastructure/` |
| `Could not resolve host` | WSL DNS for `.local` domains | Use `kubectl port-forward` instead |
| Agent node `NotReady` | containerd socket after WSL sleep | `docker restart k3d-fintech-local-agent-0` |

---

## 🗺️ Roadmap

```mermaid
graph LR
    P1["Phase 1\n✅ K3d + ArgoCD\nPlatform Bootstrap"]
    P2["Phase 2\n✅ Containerised\nPayment Service"]
    P3["Phase 3\n✅ GitOps\nApp of Apps"]
    P4["Phase 4\n⬜ Observability\nPrometheus + Grafana\n+ Loki"]
    P5["Phase 5\n⬜ EKS Migration\nAWS managed K8s\nIRSA + ALB Controller"]
    P6["Phase 6\n⬜ Service Mesh\nIstio mTLS\nTraffic management"]

    P1 --> P2 --> P3 --> P4 --> P5 --> P6

    style P1 fill:#22c55e,color:#fff
    style P2 fill:#22c55e,color:#fff
    style P3 fill:#22c55e,color:#fff
    style P4 fill:#94a3b8,color:#fff
    style P5 fill:#94a3b8,color:#fff
    style P6 fill:#94a3b8,color:#fff
```

---

<div align="center">

## 👤 About

**Govind — DevOps & Platform Engineering**

Experience from:
- **Ezdat Technology** — 1 Year DevOps Internship *(startup engineering pace)*
- **Yamaha, Noida** — Industrial DevOps Training *(corporate delivery standards)*

This project bridges startup engineering speed with corporate delivery discipline.

<br/>

[![GitHub](https://img.shields.io/badge/GitHub-govinddevops-100000?style=for-the-badge&logo=github&logoColor=white)](https://github.com/govinddevops)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://linkedin.com/in/your-profile)

<br/>

---

*Zero manual clicks. Zero hardcoded values. Zero compromise on security.*

**⭐ Star this repository if it helped you ⭐**

</div>

