variable "project_name" {
  type        = string
  description = "Standard naming prefix for all resources"
}

variable "environment" {
  type        = string
  description = "Target deployment environment (e.g., dev, prod)"
}

variable "discord_webhook_url" {
  type        = string
  description = "Discord incoming webhook URL for alert notifications"
  sensitive   = true
}

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster"
}

variable "frontend_service_name" {
  type        = string
  description = "Name of the ECS Frontend service"
}

variable "backend_service_name" {
  type        = string
  description = "Name of the ECS Backend service"
}

variable "alb_arn_suffix" {
  type        = string
  description = "ARN suffix of the Application Load Balancer"
}

variable "frontend_tg_arn_suffix" {
  type        = string
  description = "ARN suffix of the frontend target group"
}

variable "backend_tg_arn_suffix" {
  type        = string
  description = "ARN suffix of the backend target group"
}