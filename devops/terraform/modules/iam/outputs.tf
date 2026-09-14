output "jenkins_access_key_id" {
  description = "Access key ID for the Jenkins deployment user"
  value       = aws_iam_access_key.jenkins.id
}

output "jenkins_secret_access_key" {
  description = "Secret access key for the Jenkins deployment user"
  value       = aws_iam_access_key.jenkins.secret
  sensitive   = true
}