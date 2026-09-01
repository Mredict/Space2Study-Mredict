resource "aws_secretsmanager_secret" "backend_secrets" {
  name                    = "${var.project_name}-backend-secrets-${var.environment}"
  recovery_window_in_days = 0 # Forces immediate deletion on destroy in dev
}

resource "aws_secretsmanager_secret_version" "backend_secrets_val" {
  secret_id = aws_secretsmanager_secret.backend_secrets.id
  secret_string = jsonencode({
    MONGO_USER         = var.db_username
    MONGO_PASS         = var.db_password
    JWT_ACCESS_SECRET  = var.jwt_access_secret
    JWT_REFRESH_SECRET = var.jwt_refresh_secret
    JWT_RESET_SECRET   = var.jwt_reset_secret
    JWT_CONFIRM_SECRET = var.jwt_confirm_secret
    MAIL_USER          = var.mail_user
    MAIL_PASS          = var.mail_pass
  })
}