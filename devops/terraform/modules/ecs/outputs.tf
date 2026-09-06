output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "backend_service_name" {
  value = aws_ecs_service.backend.name
}

output "frontend_service_name" {
  value = aws_ecs_service.frontend.name
}

output "frontend_service_arn" {
  value = aws_ecs_service.frontend.id
}

output "backend_service_arn" {
  value = aws_ecs_service.backend.id
}

output "execution_role_arn" {
  value = aws_iam_role.ecs_execution_role.arn
}