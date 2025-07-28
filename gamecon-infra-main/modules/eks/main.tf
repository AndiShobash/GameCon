
# Creates the main EKS cluster with Kubernetes version 1.32
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    # Use both public and private subnets for the control plane
    # Control plane will be in public, but can reach private subnets
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true  # Keep public access for management
    public_access_cidrs     = ["0.0.0.0/0"]  
  }

    version = "1.32"
  #  Uses hybrid authentication (API + ConfigMap) for backward compatibility
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

    tags = merge(
    {
      Name = var.cluster_name
      "karpenter.sh/discovery" = var.cluster_name
    },
    var.tags
  )
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy]
}

# Tag the EKS cluster security group for Karpenter discovery
resource "aws_ec2_tag" "cluster_security_group_karpenter_discovery" {
  resource_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name

  depends_on = [aws_eks_cluster.this]
}

# Tag the EKS cluster security group with cluster ownership
resource "aws_ec2_tag" "cluster_security_group_cluster_owned" {
  resource_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "owned"

  depends_on = [aws_eks_cluster.this]
}

# Access entries for admin users
resource "aws_eks_access_entry" "admin_users" {
  for_each = toset(var.admin_users)
  
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type         = "STANDARD"
}

# Associate admin policies
resource "aws_eks_access_policy_association" "admin_policies" {
  for_each = toset(var.admin_users)
  
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin_users]
}

# Service role that the EKS service assumes to manage the cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

# Attaches AWS managed policy for EKS cluster operations
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Retrieves the TLS certificate from the EKS OIDC issuer URL
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# Creates an OIDC identity provider in AWS IAM
# Enables Kubernetes service accounts to assume IAM roles
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(
    {
      Name = "${var.cluster_name}-eks-irsa"
    },
    var.tags
  )
}