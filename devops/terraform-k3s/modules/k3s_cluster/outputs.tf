output "init_node_public_ip" {
  description = "kubectl/API endpoint - also the address ingress-nginx is reachable on"
  value       = aws_eip.init.public_ip
}

output "init_node_id" {
  value = aws_instance.init.id
}

output "join_node_ids" {
  value = aws_instance.join[*].id
}

output "all_node_ids" {
  value = merge(
    { "node-0" = aws_instance.init.id },
    { for idx, inst in aws_instance.join : "node-${idx + 1}" => inst.id }
  )
}

output "all_node_public_ips" {
  value = concat([aws_eip.init.public_ip], aws_eip.join[*].public_ip)
}
