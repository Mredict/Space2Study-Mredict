output "app_secrets_arn" {
  value = aws_secretsmanager_secret.app_secrets.arn
}

output "k3s_cluster_token_arn" {
  value = aws_secretsmanager_secret.k3s_cluster_token.arn
}
