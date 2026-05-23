################################################################################
# FILE         : platform/versions.tf
# LOCATION     : platform/versions.tf
# DESCRIPTION  : Version constraints for the platform bootstrap module.
#                This module manages Kubernetes namespaces and ArgoCD
#                deployment via Helm — entirely against the local K3d cluster.
#
# IMPORTANT:
#   This is a LOCAL backend intentionally. Platform state is per-developer
#   workstation. It does not use the S3 backend from infrastructure/ because
#   local cluster state is ephemeral — clusters are created and destroyed
#   frequently during development.
#
# AUTHOR       : DevOps Platform Engineering Team
# REPOSITORY   : aws-enterprise-3tier-infrastructure-iac
################################################################################

terraform {

  # Local backend — intentional for ephemeral local cluster state
  backend "local" {
    path = "terraform.tfstate"
  }

  required_version = ">= 1.6.0"

  required_providers {

    # Kubernetes provider — manages namespaces and cluster resources
    # Communicates with K3d cluster via kubeconfig
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }

    # Helm provider — deploys ArgoCD Helm chart into the cluster
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }

  }

}
