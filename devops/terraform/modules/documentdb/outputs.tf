output "endpoint" {
  description = "The cluster endpoint for DocumentDB"
  value       = aws_docdb_cluster.main.endpoint
}

output "mongodb_connection_string" {
  description = "Formatted connection string for the backend"
  value       = "mongodb://${var.db_username}:${var.db_password}@${aws_docdb_cluster.main.endpoint}:27017/space2study?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  sensitive   = true
}