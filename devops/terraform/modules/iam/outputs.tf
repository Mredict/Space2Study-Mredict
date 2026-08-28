output "jenkins_access_key_id" {
  description = "Access Key ID for Jenkins (Configure in Jenkins Credentials)"
  value       = aws_iam_access_key.jenkins_keys.id
}

output "jenkins_secret_access_key" {
  description = "Secret Access Key for Jenkins (Configure in Jenkins Credentials)"
  value       = aws_iam_access_key.jenkins_keys.secret
  sensitive   = true
}