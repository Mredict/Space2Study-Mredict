# ----------------------------------------------------------------------------
# File: modules/k3s/security_group.tf
# ----------------------------------------------------------------------------

resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-k3s-sg-${var.environment}"
  description = "Security group for K3s master node (NGINX Ingress & ArgoCD)"
  vpc_id      = var.vpc_id

  # 1. Inbound HTTP - Routed by NGINX Ingress to Frontend and ArgoCD
  ingress {
    description = "HTTP to Ingress Controller"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 2. Inbound HTTPS - Routed by NGINX Ingress
  ingress {
    description = "HTTPS to Ingress Controller"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 3. Kubernetes API Server - Internal VPC communication / local admin
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 4. Outbound Egress - Package installs, ECR image pulls, Secrets Manager
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-k3s-sg-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}