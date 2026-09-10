output "k3s_api_endpoint" {
  description = "https://<this>:6443 - use with scripts/get-kubeconfig.sh"
  value       = module.k3s_cluster.init_node_public_ip
}

output "node_public_ips" {
  value = module.k3s_cluster.all_node_public_ips
}

output "node_instance_ids" {
  description = "Map of node-0/node-1/node-2 -> EC2 instance ID"
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

output "jenkins_access_key_id" {
  description = "Paste into a Jenkins 'Username with password' credential as the username"
  value       = module.iam.jenkins_access_key_id
}

output "jenkins_secret_access_key" {
  description = "Paste into the same Jenkins credential as the password"
  value       = module.iam.jenkins_secret_access_key
  sensitive   = true
}