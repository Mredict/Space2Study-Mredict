resource "aws_secretsmanager_secret" "backend_secrets" {
  name        = "${var.project_name}-backend-secrets-${var.environment}"
  description = "Backend API Secrets (JWT, Mail, OAuth)"
  
  # DevSecOps: Ensures secrets are permanently deleted after 7 days if destroyed
  recovery_window_in_days = 7 
}

resource "aws_secretsmanager_secret_version" "backend_secrets_version" {
  secret_id     = aws_secretsmanager_secret.backend_secrets.id
  secret_string = jsonencode({
    MAIL_USER           = "placeholder_or_injected_at_apply"
    MAIL_PASS           = "placeholder_or_injected_at_apply"
    GMAIL_CLIENT_ID     = "placeholder_or_injected_at_apply"
    GMAIL_CLIENT_SECRET = "placeholder_or_injected_at_apply"
    GMAIL_REFRESH_TOKEN = "placeholder_or_injected_at_apply"
    JWT_ACCESS_SECRET   = "placeholder_or_injected_at_apply"
    JWT_REFRESH_SECRET  = "placeholder_or_injected_at_apply"
    JWT_RESET_SECRET    = "placeholder_or_injected_at_apply"
    JWT_CONFIRM_SECRET  = "placeholder_or_injected_at_apply"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}