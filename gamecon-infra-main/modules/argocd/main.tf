
terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.11.3"
    }
  }
}


# Create ArgoCD namespace
resource "kubernetes_namespace" "argocd_namespace" {
  metadata {
    name = "argocd"
    labels = {
      name = "argocd"
    }
  }
}

# Grab SSH key from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "gitops_ssh_key" {
  count     = var.gitops_ssh_secret_arn != "" ? 1 : 0
  secret_id = var.gitops_ssh_secret_arn  
}

# Create a kubernetes secret for the SSH key so ArgoCD can access it
resource "kubernetes_secret" "argocd_ssh_key" {
  count = var.gitops_ssh_secret_arn != "" ? 1 : 0
  
  metadata {
    name      = "argocd-ssh-key"
    namespace = kubernetes_namespace.argocd_namespace.metadata[0].name
    # ArgoCD will not be able to access the secret without this label
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  # Repository values - matching your argocd-app.yaml format
  data = {
    sshPrivateKey = jsondecode(data.aws_secretsmanager_secret_version.gitops_ssh_key[0].secret_string).sshPrivateKey
    type          = "git"
    url           = var.gitops_repo_url
    name          = "gitlab"  
    project       = "default"
  }

  type       = "Opaque"
  depends_on = [kubernetes_namespace.argocd_namespace]
}

# Install ArgoCD using Helm
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = kubernetes_namespace.argocd_namespace.metadata[0].name
  create_namespace = false  # We already created it above
  wait             = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version

  # Pass helm chart values
  values = [
    file(var.argocd_values_filepath)
  ]

  # Wait for namespace and SSH key (if exists)
  depends_on = [
    kubernetes_namespace.argocd_namespace,
    kubernetes_secret.argocd_ssh_key
  ]
}

# Bootstrap application to point to GitOps repo
resource "kubectl_manifest" "bootstrap_application" {
  count = var.bootstrap_application_path != "" ? 1 : 0
  
  depends_on = [helm_release.argocd]
  yaml_body  = file(var.bootstrap_application_path)
}

# Deploy GameCon application after infrastructure is ready
resource "kubectl_manifest" "gamecon_application" {
  count = var.deploy_gamecon && var.gamecon_application_path != "" ? 1 : 0
  
  depends_on = [
    helm_release.argocd,
    kubectl_manifest.bootstrap_application
  ]
  
  yaml_body = file(var.gamecon_application_path)
}