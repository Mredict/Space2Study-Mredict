output "secret_arn" {
  value = aws_secretsmanager_secret.backend_secrets.arn
}