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

variable "db_username" {
  description = "Master username for DocumentDB"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master password for DocumentDB"
  type        = string
  sensitive   = true
}