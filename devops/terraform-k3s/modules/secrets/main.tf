resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.project_name}-app-secrets-${var.environment}"
  recovery_window_in_days = 7
}

resource "random_password" "mongo_keyfile" {
  # MongoDB replica-set internal auth keyfile
  length  = 90
  special = false
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    DB_USERNAME         = var.db_username
    DB_PASSWORD         = var.db_password
    MONGO_KEYFILE       = random_password.mongo_keyfile.result
    JWT_ACCESS_SECRET   = var.jwt_access_secret
    JWT_REFRESH_SECRET  = var.jwt_refresh_secret
    JWT_RESET_SECRET    = var.jwt_reset_secret
    JWT_CONFIRM_SECRET  = var.jwt_confirm_secret
    MAIL_USER           = var.mail_user
    MAIL_PASS           = var.mail_pass
    GMAIL_CLIENT_ID     = var.gmail_client_id
    GMAIL_CLIENT_SECRET = var.gmail_client_secret
    GMAIL_REFRESH_TOKEN = var.gmail_refresh_token
    GMAIL_REDIRECT_URI  = var.gmail_redirect_uri
  })
}

# k3s cluster join token
resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "k3s_cluster_token" {
  name                    = "${var.project_name}-k3s-cluster-token-${var.environment}"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "k3s_cluster_token" {
  secret_id     = aws_secretsmanager_secret.k3s_cluster_token.id
  secret_string = random_password.k3s_token.result
}
