variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  type    = string
  default = "space2study"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "api_server_allowed_cidrs" {
  description = "Public IPs allowed to reach the k3s API server (port 6443)"
  type = list(string)
}

variable "control_plane_instance_type" {
  description = "Instance type for the control plane node"

  type    = string
  default = "t3.small"
}

variable "worker_instance_type" {
  description = "Instance type for the worker nodes"
  type        = string
  default     = "t3.small"
}

variable "worker_count" {
  description = "MongoDB's replica count."
  type    = number
  default = 2
}

variable "root_volume_gb" {
  type    = number
  default = 20
}

variable "mongo_data_volume_gb" {
  description = "Size of the extra EBS volume attached to each node for local MongoDB data"
  type        = number
  default     = 15
}

variable "budget_limit_usd" {
  description = "Hard monthly budget ceiling"
  type        = number
  default     = 100
}

variable "budget_alert_emails" {
  description = "Emails to notify on budget thresholds"
  type        = list(string)
  default     = []
}

variable "discord_webhook_url" {
  type      = string
  sensitive = true
}

# ---- Application secrets ----

variable "db_username" {
  type    = string
  default = "dbadmin"
}

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
  type    = string
  default = "https://developers.google.com/oauthplayground"
}
