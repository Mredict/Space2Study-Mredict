# 1. VPC Network Layer
module "networking" {
  source             = "../../modules/vpc"
  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"]
}

# 2. Container Registry (ECR)
module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
  environment  = var.environment
}

# 3. Application Secrets
module "secrets" {
  source              = "../../modules/secrets"
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

# 4. K3s Kubernetes Node
module "k3s" {
  source           = "../../modules/k3s"
  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.networking.vpc_id
  public_subnet_id = module.networking.public_subnets[0]
  secret_arn       = module.secrets.secret_arn
}