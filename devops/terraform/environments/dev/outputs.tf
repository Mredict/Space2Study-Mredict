output "application_endpoint" {
  description = "Public IP for your application"
  value       = "http://${module.k3s.public_ip}"
}

output "jenkins_aws_access_key_id" {
  value = module.iam.jenkins_access_key_id
}

output "jenkins_aws_secret_access_key" {
  value     = module.iam.jenkins_secret_access_key
  sensitive = true
}