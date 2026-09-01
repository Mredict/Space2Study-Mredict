# Deployment metadata
environment  = "dev"
project_name = "space2study"
aws_region   = "eu-central-1"
image_tag    = "latest"

# Database credentials
db_username = "dbadmin"
db_password = "SuperSecretDbPassword123!"

# JWT Signing Secrets (use strong random strings)
jwt_access_secret  = "dev-jwt-access-secret-key-32-chars-min"
jwt_refresh_secret = "dev-jwt-refresh-secret-key-32-chars-min"
jwt_reset_secret   = "dev-jwt-reset-secret-key-32-chars-min"
jwt_confirm_secret = "dev-jwt-confirm-secret-key-32-chars-min"

# Superuser / Mail credentials
mail_user = "support@space2study.dev"
mail_pass = "dev-mail-password-placeholder"