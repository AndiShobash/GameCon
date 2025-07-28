output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd_namespace.metadata[0].name
}

output "argocd_server_service_name" {
  description = "ArgoCD server service name"
  value       = "argocd-server"
}

output "helm_release_status" {
  description = "Helm release status"
  value       = helm_release.argocd.status
}

output "ssh_key_configured" {
  description = "Whether SSH key was configured"
  value       = var.gitops_ssh_secret_arn != "" ? true : false
}

output "bootstrap_app_configured" {
  description = "Whether bootstrap application was configured"
  value       = var.bootstrap_application_path != "" ? true : false
}

output "gamecon_app_configured" {
  description = "Whether GameCon application was configured"
  value       = var.deploy_gamecon && var.gamecon_application_path != "" ? true : false
}
