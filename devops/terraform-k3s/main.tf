# 1. Network
module "networking" {
  source       = "./modules/vpc"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

# 2. Security groups
module "security_groups" {
  source                   = "./modules/security_groups"
  project_name             = var.project_name
  environment              = var.environment
  vpc_id                   = module.networking.vpc_id
  api_server_allowed_cidrs = var.api_server_allowed_cidrs
}

# 3. ECR
module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
  environment  = var.environment
}

# 4. Secrets
module "secrets" {
  source              = "./modules/secrets"
  project_name        = var.project_name
  environment         = var.environment
  db_username         = var.db_username
  db_password         = var.db_password
  jwt_access_secret   = var.jwt_access_secret
  jwt_refresh_secret  = var.jwt_refresh_secret
  jwt_reset_secret    = var.jwt_reset_secret
  jwt_confirm_secret  = var.jwt_confirm_secret
  mail_user           = var.mail_user
  mail_pass           = var.mail_pass
  gmail_client_id     = var.gmail_client_id
  gmail_client_secret = var.gmail_client_secret
  gmail_refresh_token = var.gmail_refresh_token
  gmail_redirect_uri  = var.gmail_redirect_uri
}

# 5. IAM
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
  ecr_repository_arns = [
    module.ecr.frontend_repository_arn,
    module.ecr.backend_repository_arn,
  ]
  k3s_token_secret_arn = module.secrets.k3s_cluster_token_arn
  app_secrets_arn      = module.secrets.app_secrets_arn
}

# 6. k3s cluster
module "k3s_cluster" {
  source                      = "./modules/k3s_cluster"
  project_name                = var.project_name
  environment                 = var.environment
  aws_region                  = var.aws_region
  control_plane_instance_type = var.control_plane_instance_type
  worker_instance_type        = var.worker_instance_type
  worker_count                = var.worker_count
  root_volume_gb              = var.root_volume_gb
  mongo_data_volume_gb        = var.mongo_data_volume_gb
  public_subnets              = module.networking.public_subnets
  node_sg_id                  = module.security_groups.k3s_node_sg_id
  node_instance_profile_name  = module.iam.k3s_node_instance_profile_name
  k3s_token_secret_arn        = module.secrets.k3s_cluster_token_arn
  k3s_version                 = var.k3s_version
}

# 7. Monitoring
module "monitoring" {
  source               = "./modules/monitoring"
  project_name         = var.project_name
  environment          = var.environment
  discord_webhook_url  = var.discord_webhook_url
  node_instance_ids    = module.k3s_cluster.all_node_ids
}

# 8. Budget guardrail
module "budget" {
  source               = "./modules/budget"
  project_name         = var.project_name
  environment          = var.environment
  budget_limit_usd     = var.budget_limit_usd
  budget_alert_emails  = var.budget_alert_emails
  sns_topic_arn        = module.monitoring.sns_topic_arn
}
