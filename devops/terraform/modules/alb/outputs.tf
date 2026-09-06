output "alb_dns_name" {
  description = "The public endpoint URL for your application"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "backend_target_group_arn" {
  value = aws_lb_target_group.backend.arn
}

output "frontend_target_group_arn" {
  value = aws_lb_target_group.frontend.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the ALB for CloudWatch dimensions"
  value       = aws_lb.main.arn_suffix
}

output "frontend_tg_arn_suffix" {
  description = "ARN suffix of the Frontend target group for CloudWatch dimensions"
  value       = aws_lb_target_group.frontend.arn_suffix
}

output "backend_tg_arn_suffix" {
  description = "ARN suffix of the Backend target group for CloudWatch dimensions"
  value       = aws_lb_target_group.backend.arn_suffix
}