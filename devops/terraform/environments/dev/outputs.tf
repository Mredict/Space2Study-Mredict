output "alb_dns_name" {
  description = "The public endpoint URL for the application load balancer"
  value       = module.alb.alb_dns_name
}