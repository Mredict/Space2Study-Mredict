output "k3s_node_instance_profile_name" {
  value = aws_iam_instance_profile.k3s_node.name
}

output "eso_access_key_id" {
  description = "For the ONE-TIME `kubectl create secret` in scripts/bootstrap-cluster-addons.sh - not used anywhere else"
  value       = aws_iam_access_key.eso_secrets_reader.id
}

output "eso_secret_access_key" {
  value     = aws_iam_access_key.eso_secrets_reader.secret
  sensitive = true
}

output "jenkins_access_key_id" {
  value = aws_iam_access_key.jenkins_static.id
}

output "jenkins_secret_access_key" {
  value     = aws_iam_access_key.jenkins_static.secret
  sensitive = true
}

output "cosign_key_uri" {
  description = "Paste this EXACTLY as the 'cosign-private-key' Jenkins credential (Secret text kind) - no assembly needed"
  value       = "awskms:///${aws_kms_key.cosign_signing.arn}"
}
