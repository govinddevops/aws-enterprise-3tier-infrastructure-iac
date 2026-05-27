# 🚀 Production Cloud Migration Blueprints

## What This Folder Contains

Architecture blueprints and Kubernetes manifests for migrating this
local K3d platform to AWS EKS. These are **reference designs** — not
deployed infrastructure. They demonstrate production-readiness
and cloud migration awareness.

## Migration Delta: Local K3d → AWS EKS

| Component | Local (K3d) | Production (EKS) |
|---|---|---|
| Cluster | K3d on laptop | AWS EKS managed control plane |
| Ingress | NGINX Ingress | AWS Load Balancer Controller |
| Storage | Local filesystem | Amazon EBS CSI Driver |
| Identity | K8s ServiceAccount | IRSA (IAM Roles for Service Accounts) |
| Secrets | K8s ConfigMap | AWS Secrets Manager via CSI |
| DNS | /etc/hosts | Route 53 + ExternalDNS |
| TLS | None (local) | ACM + cert-manager |
| Monitoring | Local Prometheus | Amazon Managed Prometheus |
| Logging | Local Loki | Amazon CloudWatch Logs |

## Files in This Folder

| File | Purpose |
|---|---|
| `eks/cluster-blueprint.yaml` | EKS cluster Terraform reference |
| `irsa/irsa-blueprint.yaml` | IRSA ServiceAccount annotation pattern |
| `rbac/eks-rbac-blueprint.yaml` | EKS RBAC + aws-auth ConfigMap pattern |
| `alb-controller/alb-controller-blueprint.yaml` | AWS LB Controller Ingress pattern |

## Honest Scope Statement

These blueprints demonstrate architectural awareness and
migration readiness. They are not validated against a live
AWS account — intentionally local-first to remain zero-cost.
