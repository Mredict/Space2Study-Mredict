variable "project_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "vpc_id" { type = string }
variable "private_subnets" { type = list(string) }
variable "db_sg_id" { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "ecs_cluster_id" { type = string }
variable "execution_role_arn" { type = string }