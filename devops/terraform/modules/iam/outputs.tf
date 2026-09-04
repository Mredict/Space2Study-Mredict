output "trust_anchor_arn" {
  description = "ARN of the IAM Roles Anywhere Trust Anchor"
  value       = aws_rolesanywhere_trust_anchor.jenkins.arn
}

output "profile_arn" {
  description = "ARN of the IAM Roles Anywhere Profile"
  value       = aws_rolesanywhere_profile.jenkins_profile.arn
}

output "role_arn" {
  description = "ARN of the IAM Role assumed via Roles Anywhere"
  value       = aws_iam_role.jenkins_roles_anywhere.arn
}