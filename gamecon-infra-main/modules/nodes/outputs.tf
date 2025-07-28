
output "node_group_name" {
  value = aws_eks_node_group.this.node_group_name
}
output "node_group_arn" {
  value = aws_eks_node_group.this.arn
}
output "node_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = aws_iam_role.eks_node_role.arn
}