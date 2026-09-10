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

variable "node_instance_type" {
  description = "Instance type for the k3s server nodes (control-plane + worker combined)"
  type        = string
  default     = "t3.small"
}

variable "node_count" {
  description = "Number of k3s server nodes (odd number for embedded-etcd quorum: 1 or 3)"
  type        = number
  default     = 3

  validation {
    condition     = contains([1, 3, 5], var.node_count)
    error_message = "node_count must be 1, 3, or 5 (etcd quorum requires an odd number)."
  }
}

variable "root_volume_gb" {
  type    = number
  default = 20
}

variable "mongo_data_volume_gb" {
  description = "Size of the extra EBS volume attached to each node for local MongoDB data (used by local-path storage class, see README on the EBS CSI alternative)"
  type        = number
  default     = 15
}

variable "budget_limit_usd" {
  description = "Hard monthly budget ceiling to alert against. You said you have $100 total - alerts fire well before that."
  type        = number
  default     = 100
}

variable "budget_alert_emails" {
  description = "Emails to notify on budget thresholds, in addition to the Discord webhook"
  type        = list(string)
  default     = []
}

variable "discord_webhook_url" {
  type      = string
  sensitive = true
}

variable "jenkins_ca_cert_path" {
  description = "Path to the self-managed CA public certificate PEM (see scripts/generate-jenkins-ca.sh)"
  type        = string
  default     = "../pki/jenkins-ca.crt"
}

# ---- Application secrets

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
