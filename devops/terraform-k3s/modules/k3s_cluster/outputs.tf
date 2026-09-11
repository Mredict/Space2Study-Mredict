output "control_plane_public_ip" {
  description = "kubectl/API endpoint"
  value       = aws_eip.control_plane.public_ip
}

output "control_plane_id" {
  value = aws_instance.control_plane.id
}

output "worker_ids" {
  value = aws_instance.worker[*].id
}

output "all_node_ids" {
  value = merge(
    { "control-plane" = aws_instance.control_plane.id },
    { for idx, inst in aws_instance.worker : "worker-${idx}" => inst.id }
  )
}

output "all_node_public_ips" {
  value = concat([aws_eip.control_plane.public_ip], aws_eip.worker[*].public_ip)
}

output "worker_public_ips" {
  description = "The application's actual entry point (ingress-nginx runs on workers only, since the control plane is tainted) - use one of these, not control_plane_public_ip, to reach the app"
  value       = aws_eip.worker[*].public_ip
}
