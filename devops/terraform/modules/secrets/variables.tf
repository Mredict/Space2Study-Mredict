variable "project_name" { type = string }
variable "environment" { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
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