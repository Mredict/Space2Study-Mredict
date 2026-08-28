output "backend_secrets_arn" {
  description = "The ARN of the backend Secrets Manager secret"
  value       = aws_secretsmanager_secret.backend_secrets.arn
}