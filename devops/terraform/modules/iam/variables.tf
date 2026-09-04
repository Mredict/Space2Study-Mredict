variable "project_name" { type = string }
variable "environment" { type = string }
variable "frontend_ecr_arn" { type = string }
variable "backend_ecr_arn" { type = string }
variable "frontend_ecs_service_id" { type = string }
variable "backend_ecs_service_id" { type = string }
variable "root_ca_certificate" {
  description = "PEM encoded X.509 Root CA certificate for IAM Roles Anywhere"
  type        = string
}