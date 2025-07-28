variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "argocd_values_filepath" {
  description = "Path to ArgoCD Helm values file"
  type        = string
}

variable "argocd_chart_version" {
  description = "Version of ArgoCD Helm chart"
  type        = string
  default     = "5.53.13"
}

variable "bootstrap_application_path" {
  description = "Path to bootstrap application YAML file"
  type        = string
  default     = ""  # Optional
}

# AWS Secrets Manager approach for SSH key
variable "gitops_ssh_secret_arn" {
  description = "ARN of AWS Secret containing SSH private key for GitOps repo"
  type        = string
  default     = ""
}

variable "gitops_repo_url" {
  description = "Git repository URL for GitOps"
  type        = string
  default     = ""
}

variable "gamecon_application_path" {
  description = "Path to GameCon application YAML file"
  type        = string
  default     = ""
}

variable "deploy_gamecon" {
  description = "Whether to deploy GameCon application"
  type        = bool
  default     = false
}