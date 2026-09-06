output "mongodb_connection_string" {
  description = "Formatted connection string for the backend"
  value       = "mongodb://${var.db_username}:${var.db_password}@mongodb.local:27017/space2study?authSource=admin"
  sensitive   = true
}