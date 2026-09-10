data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}


# 1. EC2 Instance (t3.micro - Free Tier)
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

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 1. Configure 2.5GB swap space to ensure stability for ArgoCD + apps
              fallocate -l 2560M /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab

              # 2. Install prerequisites
              apt-get update -y
              apt-get install -y curl unzip git

              # 3. Pre-create K3s manifests directory
              mkdir -p /var/lib/rancher/k3s/server/manifests

              # 4. Ingress-NGINX Auto-Deploy
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
                        cpu: 40m
                        memory: 80Mi
                      limits:
                        cpu: 150m
                        memory: 150Mi
              YAML

              # 5. Install K3s
              curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik --disable=servicelb --write-kubeconfig-mode=644" sh -

              # 6. Wait for Kubernetes API to become ready
              until kubectl get nodes; do sleep 3; done

              # 7. Install ArgoCD
              kubectl create namespace argocd || true
              kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

              # 8. Deploy Space2Study Application to ArgoCD
              cat <<'YAML' > /var/lib/rancher/k3s/server/manifests/argocd-space2study-app.yaml
              apiVersion: argoproj.io/v1alpha1
              kind: Application
              metadata:
                name: space2study-${var.environment}
                namespace: argocd
              spec:
                project: default
                source:
                  repoURL: 'https://github.com/Mredict/Space2Study-Mredict.git'
                  targetRevision: HEAD
                  path: devops/helm/space2study
                  helm:
                    valueFiles:
                      - values.yaml
                destination:
                  server: 'https://kubernetes.default.svc'
                  namespace: space2study-${var.environment}
                syncPolicy:
                  automated:
                    prune: true
                    selfHeal: true
                  syncOptions:
                    - CreateNamespace=true
              YAML
              EOF

  tags = {
    Name = "${var.project_name}-k3s-${var.environment}"
  }
}

# 2. Elastic IP
resource "aws_eip" "k3s" {
  instance = aws_instance.k3s_server.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-k3s-eip-${var.environment}"
  }
}