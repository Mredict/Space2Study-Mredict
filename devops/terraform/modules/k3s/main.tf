data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 1. Security Group
resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-k3s-sg-${var.environment}"
  description = "Allows direct Web traffic to NGINX and cluster administration"
  vpc_id      = var.vpc_id

  # HTTP
  ingress {
    description = "HTTP to Ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS to Ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes API
  ingress {
    description = "K8s API endpoint"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-k3s-sg-${var.environment}"
  }
}

# 2. EC2 Instance
resource "aws_instance" "k3s_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.k3s.id]
  iam_instance_profile   = aws_iam_instance_profile.k3s_profile.name

  root_block_device {
    volume_size           = 25
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Automatic K3s + Automatic Ingress-NGINX installation
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 1. Setup 2GB Swap to protect 1GB RAM from OOM crashes
              fallocate -l 2G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab

              # 2. Install basic utilities
              apt-get update -y
              apt-get install -y curl unzip

              # 3. Pre-create K3s manifests directory
              mkdir -p /var/lib/rancher/k3s/server/manifests

              # 4. Automate NGINX Ingress using K3s HelmChart CRD
              cat <<'YAML' > /var/lib/rancher/k3s/server/manifests/ingress-nginx.yaml
              apiVersion: helm.cattle.io/v1
              kind: HelmChart
              metadata:
                name: ingress-nginx
                namespace: kube-system
              spec:
                chart: ingress-nginx
                repo: https://kubernetes.github.io/ingress-nginx
                targetNamespace: ingress-nginx
                createNamespace: true
                valuesContent: |-
                  controller:
                    kind: DaemonSet
                    hostPort:
                      enabled: true
                    service:
                      type: ClusterIP
                    resources:
                      requests:
                        cpu: 50m
                        memory: 90Mi
                      limits:
                        cpu: 200m
                        memory: 180Mi
              YAML

              # 5. Install K3s (disable Traefik and ServiceLB since NGINX uses hostPort)
              curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik --disable=servicelb --write-kubeconfig-mode=644" sh -

              # 6. Install Helm CLI locally on node
              curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
              EOF

  tags = {
    Name = "${var.project_name}-k3s-${var.environment}"
  }
}

# 3. Elastic IP
resource "aws_eip" "k3s" {
  instance = aws_instance.k3s_server.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-k3s-eip-${var.environment}"
  }
}