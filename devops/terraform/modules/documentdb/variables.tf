variable "project_name" { type = string }
variable "environment" { type = string }
variable "private_subnets" { type = list(string) }
variable "db_sg_id" { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}