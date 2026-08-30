# 1. Network Layer
module "networking" {
  source             = "../../modules/vpc"
  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"]
}

# 2. Firewalls & Security Groups
module "security_groups" {
  source       = "../../modules/security_groups"
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
}

# 3. ECR Registries
module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
  environment  = var.environment
}

# 4. Public Load Balancer
module "alb" {
  source         = "../../modules/alb"
  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.networking.vpc_id
  public_subnets = module.networking.public_subnets
  alb_sg_id      = module.security_groups.alb_sg_id
}

# 5. Database Layer (Managed MongoDB)
module "documentdb" {
  source             = "../../modules/documentdb"
  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_id             = module.networking.vpc_id
  private_subnets    = module.networking.private_subnets
  db_sg_id           = module.security_groups.database_sg_id
  db_username        = var.db_username
  db_password        = var.db_password
  ecs_cluster_id     = module.ecs.cluster_name
  execution_role_arn = module.ecs.execution_role_arn
}

# 6. Container Orchestration (ECS Fargate)
module "ecs" {
  source                    = "../../modules/ecs"
  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  private_subnets           = module.networking.private_subnets
  frontend_sg_id            = module.security_groups.frontend_ecs_sg_id
  backend_sg_id             = module.security_groups.backend_ecs_sg_id
  frontend_image            = "${module.ecr.frontend_repository_url}:latest"
  backend_image             = "${module.ecr.backend_repository_url}:latest"
  mongodb_url               = module.documentdb.mongodb_connection_string
  frontend_target_group_arn = module.alb.frontend_target_group_arn
  backend_target_group_arn  = module.alb.backend_target_group_arn
}

# 7. CI/CD IAM Roles
module "iam" {
  source           = "../../modules/iam"
  project_name     = var.project_name
  environment      = var.environment
  frontend_ecr_arn = module.ecr.frontend_repository_arn
  backend_ecr_arn  = module.ecr.backend_repository_arn

  # Note: You will need to expose the service ARNs in your ecs/outputs.tf 
  frontend_ecs_service_id = module.ecs.frontend_service_arn
  backend_ecs_service_id  = module.ecs.backend_service_arn
}

# (Optional but recommended) Print credentials to the console for one-time setup
output "jenkins_aws_access_key_id" {
  value = module.iam.jenkins_access_key_id
}

output "jenkins_aws_secret_access_key" {
  value     = module.iam.jenkins_secret_access_key
  sensitive = true
}