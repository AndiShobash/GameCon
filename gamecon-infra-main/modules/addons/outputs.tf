output "ebs_csi_driver_status" {
  value = aws_eks_addon.aws_ebs_csi_driver.id
}

output "kube_proxy_status" {
  value = aws_eks_addon.kube_proxy.id
}

output "coredns_status" {
  value = aws_eks_addon.coredns.id
}

output "vpc_cni_status" {
  value = aws_eks_addon.vpc_cni.id
}

output "external_secrets_role_arn" {
  description = "ARN of the External Secrets IAM role"
  value       = aws_iam_role.external_secrets_role.arn
}

# NEW: Karpenter outputs
output "karpenter_controller_role_arn" {
  description = "ARN of the Karpenter controller IAM role"
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_node_instance_profile_name" {
  description = "Name of the Karpenter node instance profile"
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "karpenter_node_role_arn" {
  description = "ARN of the Karpenter node IAM role"
  value       = aws_iam_role.karpenter_node.arn
}