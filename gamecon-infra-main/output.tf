output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_node_group_name" {
  value = module.nodes.node_group_name
}

output "ebs_csi_driver_status" {
  value = module.addons.ebs_csi_driver_status
}

output "kube_proxy_status" {
  value = module.addons.kube_proxy_status
}

output "coredns_status" {
  value = module.addons.coredns_status
}

output "vpc_cni_status" {
  value = module.addons.vpc_cni_status
}

output "external_secrets_role_arn" {
  description = "ARN of the External Secrets IAM role"
  value       = module.addons.external_secrets_role_arn
}

output "karpenter_controller_role_arn" {
  description = "ARN of the Karpenter controller IAM role"
  value       = module.addons.karpenter_controller_role_arn
}

output "karpenter_node_instance_profile_name" {
  description = "Name of the Karpenter node instance profile"
  value       = module.addons.karpenter_node_instance_profile_name
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID for Karpenter"
  value       = module.eks.cluster_security_group_id
}

output "node_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = module.nodes.node_role_arn
}
