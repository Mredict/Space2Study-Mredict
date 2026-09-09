output "application_endpoint" {
  description = "Public IP for your application"
  value       = "http://${module.k3s.public_ip}"
}