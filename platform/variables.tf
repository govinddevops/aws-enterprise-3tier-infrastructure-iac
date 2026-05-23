################################################################################
# FILE         : platform/variables.tf
# LOCATION     : platform/variables.tf
# DESCRIPTION  : Input variables for the platform bootstrap module.
#                All values have sensible defaults matching the K3d cluster
#                configuration defined in the Makefile.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
################################################################################

################################################################################
# SECTION 1: CLUSTER CONNECTIVITY
################################################################################

variable "kubeconfig_path" {
  description = "Absolute path to the kubeconfig file used by Terraform Kubernetes and Helm providers to connect to the K3d cluster. Defaults to the standard kubeconfig location."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "The kubeconfig context name for the K3d cluster. K3d prefixes cluster names with 'k3d-' automatically. Must match the cluster name set in the Makefile CLUSTER_NAME variable."
  type        = string
  default     = "k3d-fintech-local"
}

################################################################################
# SECTION 2: PLATFORM NAMESPACES
################################################################################

variable "platform_namespaces" {
  description = "List of Kubernetes namespaces to create on the cluster. Each namespace represents a clean boundary for a platform concern — platform tooling, applications, security, and observability."
  type        = list(string)
  default = [
    "platform",      # ArgoCD, Ingress controller, platform tooling
    "apps",          # FinTech microservice applications
    "security",      # Secrets management, policy engines (future)
    "observability"  # Prometheus, Grafana, logging stack (future)
  ]
}

################################################################################
# SECTION 3: ARGOCD CONFIGURATION
################################################################################

variable "argocd_namespace" {
  description = "The Kubernetes namespace where ArgoCD will be installed. Kept separate from 'platform' namespace so ArgoCD has its own RBAC boundary and can be upgraded independently."
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "The ArgoCD Helm chart version to deploy. Pinned for reproducibility — changing this triggers a controlled ArgoCD upgrade. Check https://artifacthub.io/packages/helm/argo/argo-cd for latest."
  type        = string
  default     = "6.7.3"
}

variable "argocd_helm_repo" {
  description = "The Helm repository URL for the ArgoCD chart."
  type        = string
  default     = "https://argoproj.github.io/argo-helm"
}

variable "argocd_server_insecure" {
  description = "Run ArgoCD server without TLS termination at the ArgoCD layer. Set to true for local development where TLS is terminated at the Ingress controller instead. Never true in production."
  type        = bool
  default     = true
}

variable "argocd_ingress_enabled" {
  description = "Whether to create an Ingress resource for the ArgoCD server. Enables access via argocd.fintech.local when combined with hosts-setup make target."
  type        = bool
  default     = true
}

variable "argocd_ingress_host" {
  description = "The local domain for the ArgoCD UI Ingress rule. Must be added to /etc/hosts pointing to 127.0.0.1. Use 'make hosts-setup' to configure automatically."
  type        = string
  default     = "argocd.fintech.local"
}

################################################################################
# SECTION 4: ENVIRONMENT METADATA
################################################################################

variable "environment" {
  description = "Environment label applied as Kubernetes labels on all created namespaces. Distinguishes local platform simulation from cloud environments."
  type        = string
  default     = "local"

  validation {
    condition     = contains(["local", "dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: local, dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name applied as a label on all Kubernetes resources created by this module."
  type        = string
  default     = "enterprise-3tier"
}
