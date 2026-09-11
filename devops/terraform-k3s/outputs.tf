output "k3s_api_endpoint" {
  description = "https://<this>:6443 - use with scripts/get-kubeconfig.sh"
  value       = module.k3s_cluster.control_plane_public_ip
}

output "node_public_ips" {
  value = module.k3s_cluster.all_node_public_ips
}

output "worker_public_ips" {
  description = "Reach the app here, not at k3s_api_endpoint - ingress-nginx runs on workers only"
  value       = module.k3s_cluster.worker_public_ips
}

output "primary_worker_public_ip" {
  description = "Convenience single-value version of worker_public_ips[0], for scripts/curl one-liners"
  value       = module.k3s_cluster.worker_public_ips[0]
}

output "node_instance_ids" {
  description = "Map of control-plane/worker-0/worker-1 -> EC2 instance ID"
  value       = module.k3s_cluster.all_node_ids
}

output "frontend_ecr_url" {
  value = module.ecr.frontend_repository_url
}

output "backend_ecr_url" {
  value = module.ecr.backend_repository_url
}

output "aws_region" {
  value = var.aws_region
}

output "jenkins_access_key_id" {
  description = "Paste into a Jenkins 'Username with password' credential as the username"
  value       = module.iam.jenkins_access_key_id
}

output "jenkins_secret_access_key" {
  description = "Paste into the same Jenkins credential as the password"
  value       = module.iam.jenkins_secret_access_key
  sensitive   = true
}

output "cosign_key_uri" {
  description = "Paste EXACTLY as-is into the 'cosign-private-key' Jenkins credential (Secret text kind)"
  value       = module.iam.cosign_key_uri
}

output "eso_access_key_id" {
  description = "Used once by scripts/bootstrap-cluster-addons.sh to seed the ESO Kubernetes Secret - not stored anywhere else"
  value       = module.iam.eso_access_key_id
}

output "eso_secret_access_key" {
  value     = module.iam.eso_secret_access_key
  sensitive = true
}

output "monitoring_sns_topic_arn" {
  value = module.monitoring.sns_topic_arn
}
