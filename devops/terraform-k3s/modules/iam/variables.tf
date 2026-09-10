variable "project_name" { type = string }
variable "environment" { type = string }
variable "ecr_repository_arns" { type = list(string) }
variable "k3s_token_secret_arn" { type = string }
variable "app_secrets_arn" { type = string }