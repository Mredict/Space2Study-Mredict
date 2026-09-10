variable "project_name" { type = string }
variable "environment" { type = string }
variable "discord_webhook_url" {
  type      = string
  sensitive = true
}
variable "node_instance_ids" { type = map(string) }
