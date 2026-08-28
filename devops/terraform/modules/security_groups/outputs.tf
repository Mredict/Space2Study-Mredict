output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "frontend_ecs_sg_id" {
  value = aws_security_group.frontend_ecs.id
}

output "backend_ecs_sg_id" {
  value = aws_security_group.backend_ecs.id
}

output "database_sg_id" {
  value = aws_security_group.database.id
}