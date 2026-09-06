variable "project_name" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "private_subnets" { type = list(string) }
variable "frontend_sg_id" { type = string }
variable "backend_sg_id" { type = string }
variable "frontend_image" { type = string }
variable "backend_image" { type = string }
variable "mongodb_url" { type = string }
variable "frontend_target_group_arn" { type = string }
variable "backend_target_group_arn" { type = string }

variable "secret_arn" {
  description = "ARN of the AWS Secrets Manager secret containing application credentials"
  type        = string
}

variable "alb_dns_name" {
  description = "Public DNS name of the ALB used for CORS and callback URLs"
  type        = string
}

variable "app_secrets_arn" {
  description = "ARN of the Secrets Manager secret holding application credentials"
  type        = string
}