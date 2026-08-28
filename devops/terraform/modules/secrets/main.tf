# 1. Define the secret in Secrets Manager for the Backend
resource "aws_secretsmanager_secret" "backend_secrets" {
  name        = "${var.project_name}-backend-secrets-${var.environment}"
  description = "Backend API Secrets (JWT, Mail, OAuth)"
  
  # DevSecOps: Ensures secrets are permanently deleted after 7 days if destroyed
  recovery_window_in_days = 7 
}

# 2. Store the initial empty/placeholder JSON payload
# In a real environment, you will update these values manually in the AWS Console
# or inject them via a secure pipeline variable so they aren't hardcoded in git.
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

  # Ignore changes so Terraform doesn't overwrite your real secrets 
  # next time you run `terraform apply`
  lifecycle {
    ignore_changes = [secret_string]
  }
}