################################################################################
# FILE         : platform/main.tf
# LOCATION     : platform/main.tf
# DESCRIPTION  : Platform bootstrap — creates Kubernetes namespaces and
#                deploys ArgoCD via Helm onto the local K3d cluster.
#
# RESOURCES CREATED:
#   1. kubernetes_namespace (x5) — platform, apps, security, observability, argocd
#   2. helm_release            — ArgoCD deployed into argocd namespace
#
# DESIGN DECISION — WHY TERRAFORM FOR NAMESPACE MANAGEMENT:
#   Namespaces could be created with 'kubectl create namespace'.
#   Using Terraform gives us: state tracking, idempotency, label consistency,
#   and a single declarative file that self-documents the platform topology.
#   Any engineer running 'make platform-bootstrap' gets identical state.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
################################################################################

################################################################################
# LOCAL VALUES
# Centralised label set applied to every namespace.
# Consistent labels enable kubectl filtering and future policy enforcement.
################################################################################

locals {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "project"                      = var.project_name
    "environment"                  = var.environment
    "platform.fintech/layer"       = "infrastructure"
  }
}

################################################################################
# RESOURCE 1: PLATFORM NAMESPACES
#
# Creates one namespace per element in var.platform_namespaces list.
# for_each over a set (toset converts list to set — removes duplicates
# and provides stable iteration keys for Terraform state tracking).
#
# NAMESPACE PURPOSES:
#   platform      — ArgoCD, NGINX Ingress, platform-level tooling
#   apps          — FinTech microservice workloads (Phase 2 target)
#   security      — Secrets management, OPA/Kyverno policies (Phase 3)
#   observability — Prometheus, Grafana, Loki stack (Phase 3)
################################################################################

resource "kubernetes_namespace" "platform_namespaces" {
  for_each = toset(var.platform_namespaces)

  metadata {
    name = each.key

    labels = merge(local.common_labels, {
      "name"                       = each.key
      "platform.fintech/namespace" = each.key
    })

    annotations = {
      "platform.fintech/created-by"  = "terraform"
      "platform.fintech/environment" = var.environment
      "platform.fintech/description" = lookup(
        {
          "platform"      = "Platform tooling: ArgoCD, Ingress, certificate management"
          "apps"          = "FinTech microservice application workloads"
          "security"      = "Security tooling: secrets management, policy engines"
          "observability" = "Observability stack: metrics, logging, tracing"
        },
        each.key,
        "Platform namespace managed by Terraform"
      )
    }
  }
}

################################################################################
# RESOURCE 2: ARGOCD NAMESPACE
#
# ArgoCD gets its own dedicated namespace separate from 'platform'.
# This separation is intentional:
#   - ArgoCD has complex RBAC requirements that need isolation
#   - ArgoCD ClusterRoles are namespace-scoped for its own ns
#   - Upgrading ArgoCD does not risk disrupting other platform tools
#   - Follows the official ArgoCD installation convention
################################################################################

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace

    labels = merge(local.common_labels, {
      "name"                       = var.argocd_namespace
      "platform.fintech/namespace" = var.argocd_namespace
      "platform.fintech/component" = "gitops-controller"
    })

    annotations = {
      "platform.fintech/created-by"  = "terraform"
      "platform.fintech/description" = "ArgoCD GitOps controller — manages application delivery"
      "platform.fintech/chart"       = "argo-cd@${var.argocd_chart_version}"
    }
  }
}

################################################################################
# RESOURCE 3: ARGOCD HELM RELEASE
#
# Deploys ArgoCD onto the cluster via the official Helm chart.
# Version is pinned via var.argocd_chart_version for reproducibility.
#
# KEY CONFIGURATION CHOICES:
#
#   server.insecure = true
#     Disables TLS at ArgoCD server level for local development.
#     TLS is handled by NGINX Ingress or accessed via port-forward.
#     This is correct for local-first environments — not production.
#
#   configs.params."server.insecure" = true
#     The Helm chart v6.x uses this path for the insecure flag.
#
#   server.ingress.enabled = true/false
#     Controlled by var.argocd_ingress_enabled. When true, creates
#     an Ingress for argocd.fintech.local using NGINX ingress class.
#     Requires 'make hosts-setup' to add /etc/hosts entry.
#
#   Replicas set to 1:
#     Local K3d has 3 nodes (1 server + 2 agents). Running 1 replica
#     is honest — this is a local simulation, not production HA.
#     Claiming HA with 1 replica would be dishonest in interviews.
#
# DEPENDS ON:
#   kubernetes_namespace.argocd must exist before Helm release runs.
################################################################################

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = var.argocd_helm_repo
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = false
  # Namespace created by kubernetes_namespace.argocd above — not by Helm
  # This gives Terraform full lifecycle control over the namespace

  # Wait for all ArgoCD pods to be Running before marking apply complete
  wait          = true
  wait_for_jobs = true
  timeout       = 600
  # 10 minute timeout — generous for first-time chart pull on slow connections

  # Render Helm values inline using heredoc YAML
  # Using 'values' with yamlencode keeps the config readable and diffable
  values = [
    yamlencode({

      # ── GLOBAL ──────────────────────────────────────────────────────────
      global = {
        # Single-replica honest local deployment
        # Not HA — but matches real ArgoCD operational patterns
        image = {
          tag = "v2.10.4"
          # Pin image tag alongside chart version for full reproducibility
        }
      }

      # ── ARGOCD SERVER ────────────────────────────────────────────────────
      server = {
        # Replica count — honest single instance for local simulation
        replicas = 1

        # Disable TLS at server level — handled by Ingress or port-forward
        insecure = var.argocd_server_insecure

        ingress = {
          enabled          = var.argocd_ingress_enabled
          ingressClassName = "nginx"
          hosts            = [var.argocd_ingress_host]
          paths            = ["/"]
          pathType         = "Prefix"
          annotations = {
            "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"
            "nginx.ingress.kubernetes.io/backend-protocol"   = "HTTP"
          }
        }

        # Resource limits — conservative for local K3d node constraints
        resources = {
          limits = {
            cpu    = "500m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }

      # ── CONFIGS ──────────────────────────────────────────────────────────
      configs = {
        params = {
          # Server insecure flag via Helm chart v6.x config path
          "server.insecure" = tostring(var.argocd_server_insecure)
        }

        # ArgoCD application controller concurrency
        # Lower values = less CPU pressure on local K3d nodes
        cm = {
          "application.instanceLabelKey"   = "app.kubernetes.io/instance"
          "server.rbac.log.enforce.enable" = "false"
          "timeout.reconciliation"         = "180s"
        }
      }

      # ── APPLICATION CONTROLLER ───────────────────────────────────────────
      applicationSet = {
        replicas = 1
        resources = {
          limits   = { cpu = "250m", memory = "128Mi" }
          requests = { cpu = "50m", memory = "64Mi" }
        }
      }

      # ── REDIS ────────────────────────────────────────────────────────────
      redis = {
        resources = {
          limits   = { cpu = "200m", memory = "128Mi" }
          requests = { cpu = "50m", memory = "64Mi" }
        }
      }

      # ── REPO SERVER ──────────────────────────────────────────────────────
      repoServer = {
        replicas = 1
        resources = {
          limits   = { cpu = "500m", memory = "256Mi" }
          requests = { cpu = "100m", memory = "128Mi" }
        }
      }

      # ── DEX (OIDC) ───────────────────────────────────────────────────────
      # Disabled — using built-in admin login for local development
      # Enable and configure Dex when OIDC/SSO is needed in Phase 3
      dex = {
        enabled = false
      }

      # ── NOTIFICATIONS ────────────────────────────────────────────────────
      notifications = {
        enabled = false
        # Slack/email notifications configured in Phase 3 observability
      }

    })
  ]

  # Ensure argocd namespace exists before Helm deploy
  depends_on = [
    kubernetes_namespace.argocd
  ]
}

################################################################################
# OUTPUTS
################################################################################

output "platform_namespaces_created" {
  description = "List of platform namespaces created on the K3d cluster by Terraform."
  value       = [for ns in kubernetes_namespace.platform_namespaces : ns.metadata[0].name]
}

output "argocd_namespace" {
  description = "The namespace where ArgoCD is deployed."
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_helm_chart_version" {
  description = "The deployed ArgoCD Helm chart version. Reference this when planning upgrades."
  value       = helm_release.argocd.version
}

output "argocd_access_instructions" {
  description = "Instructions to access the ArgoCD UI after bootstrap."
  value       = <<-EOT
    ══════════════════════════════════════════════════════
    ARGOCD ACCESS INSTRUCTIONS
    ══════════════════════════════════════════════════════

    Option 1 — Port Forward (always works):
      make argocd-open
      Open: http://localhost:8080

    Option 2 — Local Ingress (requires make hosts-setup):
      Open: http://argocd.fintech.local

    Get admin password:
      make argocd-password

    Username: admin
    ══════════════════════════════════════════════════════
  EOT
}
