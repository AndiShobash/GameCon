vpc_cidr                = "10.0.0.0/16"
subnet_newbits          = 8
availability_zone_count = 2
cluster_name            = "andi-eks-cluster"
region                  = "ap-south-1"  
admin_users             = ["arn:aws:iam::793786247026:user/Andi.Shobash"]
desired_size           = 3
max_size               = 4
min_size               = 2

# ArgoCD Configuration
argocd_values_filepath     = "./argocd-files/argocd-values.yaml"
argocd_chart_version       = "8.0.10"
bootstrap_application_path = "./argocd-files/argocd-app.yaml"
gamecon_application_path = "./argocd-files/gamecon-app.yaml"

# AWS Secrets Manager Configuration
gitops_ssh_secret_arn = "arn:aws:secretsmanager:ap-south-1:793786247026:secret:andi-argocd-ssh-SK5gKd"
gitops_repo_url       = "git@gitlab.com:andishubash/gamecon-gitops.git"
