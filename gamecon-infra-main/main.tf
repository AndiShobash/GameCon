module "network" {
  source                  = "./modules/network"
  vpc_cidr                = var.vpc_cidr
  subnet_newbits          = var.subnet_newbits
  availability_zone_count = var.availability_zone_count
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  private_subnet_ids = module.network.private_subnet_ids
  public_subnet_ids  = module.network.public_subnet_ids
  admin_users        = var.admin_users
   tags              = var.tags
}

module "nodes" {
  source             = "./modules/nodes"
  cluster_name       = module.eks.cluster_name
  private_subnet_ids = module.network.private_subnet_ids
  public_subnet_ids =  module.network.public_subnet_ids
  desired_size       = var.desired_size
  max_size           = var.max_size
  min_size           = var.min_size
  tags               = var.tags
}

module "addons" {
  source        = "./modules/addons"
  cluster_name  = module.eks.cluster_name
  cluster_oidc_issuer_url  = module.eks.cluster_oidc_issuer_url  
  oidc_provider_arn        = module.eks.oidc_provider_arn
  eks_node_role_arn        = module.nodes.node_role_arn      
  depends_on   = [module.nodes]
}

module "argocd" {
  source                     = "./modules/argocd"
  cluster_name               = module.eks.cluster_name
  argocd_values_filepath     = var.argocd_values_filepath
  argocd_chart_version       = var.argocd_chart_version
  bootstrap_application_path = var.bootstrap_application_path
  gitops_ssh_secret_arn      = var.gitops_ssh_secret_arn
  gitops_repo_url            = var.gitops_repo_url
  deploy_gamecon             = true
  gamecon_application_path   = var.gamecon_application_path
  
  depends_on = [
    module.eks,
    module.nodes,
    module.addons
  ]
}
