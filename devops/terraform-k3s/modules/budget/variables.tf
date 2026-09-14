variable "project_name" { type = string }
variable "environment" { type = string }
variable "budget_limit_usd" { type = number }
variable "budget_alert_emails" { type = list(string) }
variable "sns_topic_arn" { type = string }
