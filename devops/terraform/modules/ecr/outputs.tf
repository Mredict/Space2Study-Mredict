output "frontend_repository_url" {
  description = "ECR URL for the Frontend Docker repository"
  value       = aws_ecr_repository.frontend.repository_url
}

output "backend_repository_url" {
  description = "ECR URL for the Backend Docker repository"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_repository_arn" {
  value = aws_ecr_repository.frontend.arn
}

output "backend_repository_arn" {
  value = aws_ecr_repository.backend.arn
}