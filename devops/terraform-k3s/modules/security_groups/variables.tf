variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "api_server_allowed_cidrs" { type = list(string) }
