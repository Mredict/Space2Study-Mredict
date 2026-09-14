output "public_ip" {
  description = "Public Elastic IP to point DNS and access NGINX"
  value       = aws_eip.k3s.public_ip
}

output "instance_id" {
  value = aws_instance.k3s_server.id
}