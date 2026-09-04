variable "project_name" {
  type = string
}

variable "environment" {
  type = string
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
  type = string
}

variable "mail_pass" {
  type      = string
  sensitive = true
}

variable "gmail_client_id" {
  type = string
}

variable "gmail_client_secret" {
  type      = string
  sensitive = true
}

variable "gmail_refresh_token" {
  type      = string
  sensitive = true
}

variable "gmail_redirect_uri" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}