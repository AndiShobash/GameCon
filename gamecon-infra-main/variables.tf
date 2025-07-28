variable "region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Name            = "andi-eks-terra"
    owner           = "Andi.Shobash"
    bootcamp        = "BC24"
    expiration_date = "31-07-25"
  }
}
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_newbits" {
  description = "Bits to add when carving subnets out of the VPC CIDR"
  type        = number
}

variable "availability_zone_count" {
  description = "Number of availability zones to use"
  type        = number
}
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "desired_size" {
  description = "Desired number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
  default     = 3
}

variable "min_size" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
  default     = 1
}

variable "admin_users" {
  description = "List of IAM user ARNs to grant EKS cluster admin access"
  type        = list(string)
  default     = ["arn:aws:iam::793786247026:user/Andi.Shobash"]
}

# ArgoCD Variables
variable "argocd_values_filepath" {
  description = "Path to ArgoCD Helm values file"
  type        = string
  default     = "./argocd-values.yaml"
}

variable "argocd_chart_version" {
  description = "Version of ArgoCD Helm chart"
  type        = string
  default     = "5.53.13"
}

variable "bootstrap_application_path" {
  description = "Path to bootstrap application YAML file"
  type        = string
  default     = ""
}

# AWS Secrets Manager for SSH Key
variable "gitops_ssh_secret_arn" {
  description = "ARN of AWS Secret containing SSH private key for GitOps repo"
  type        = string
}

variable "gitops_repo_url" {
  description = "Git repository URL for GitOps"
  type        = string
}
variable "gamecon_application_path" {
  description = "Path to GameCon application YAML file"
  type        = string
  default     = "" 
}