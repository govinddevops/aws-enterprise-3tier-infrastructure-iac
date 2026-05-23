################################################################################
# FILE         : platform/providers.tf
# LOCATION     : platform/providers.tf
# DESCRIPTION  : Kubernetes and Helm provider configuration for local K3d
#                cluster bootstrap.
#
# HOW THIS CONNECTS TO THE CLUSTER:
#   Both providers read the kubeconfig file at var.kubeconfig_path and
#   use the context named var.kube_context (k3d-fintech-local by default).
#   K3d writes this context automatically when 'make cluster-up' runs
#   via: k3d kubeconfig merge fintech-local --kubeconfig-switch-context
#
# WHY NOT USE in-cluster config:
#   Terraform runs on the local workstation — not inside the cluster.
#   In-cluster config applies only to pods running inside Kubernetes.
#   External kubeconfig is the correct approach for local Terraform management.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
################################################################################

provider "kubernetes" {
  # Path to kubeconfig — defaults to ~/.kube/config
  config_path = var.kubeconfig_path

  # Explicit context name prevents accidental apply against wrong cluster
  # k3d prefixes all cluster names with "k3d-" automatically
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}
