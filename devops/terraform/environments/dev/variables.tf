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
  description = "Sender email address for application notifications"
  type        = string
}

variable "mail_pass" {
  description = "Superuser initial admin password"
  type        = string
  sensitive   = true
}

variable "gmail_client_id" {
  description = "Google OAuth 2.0 Client ID"
  type        = string
}

variable "gmail_client_secret" {
  description = "Google OAuth 2.0 Client Secret"
  type        = string
  sensitive   = true
}

variable "gmail_refresh_token" {
  description = "Google OAuth 2.0 Refresh Token"
  type        = string
  sensitive   = true
}

variable "gmail_redirect_uri" {
  description = "Google OAuth 2.0 Redirect URI"
  type        = string
  default     = "https://developers.google.com/oauthplayground"
}