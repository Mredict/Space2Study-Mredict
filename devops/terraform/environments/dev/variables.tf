variable "aws_region" {
  description = "The AWS region to deploy infrastructure into"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "space2study"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "db_username" {
  description = "Master username for DocumentDB / MongoDB"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password for DocumentDB / MongoDB"
  type        = string
  sensitive   = true
}

variable "jwt_access_secret" {
  type      = string
  sensitive = true
}

variable "jwt_refresh_secret" {
  type      = string
  sensitive = true
}

variable "jwt_reset_secret" {
  type      = string
  sensitive = true
}

variable "jwt_confirm_secret" {
  type      = string
  sensitive = true
}

variable "mail_user" {
  type    = string
  default = ""
}

variable "mail_pass" {
  type      = string
  default   = ""
  sensitive = true
}