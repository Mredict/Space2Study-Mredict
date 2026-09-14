# 🚀 Space2Study

## 📌 Deployment Methods
* [Method 1: Vagrant + Ansible (Without Docker)](#-method-1-vagrant--ansible-without-docker)
* [Method 2: Vagrant + Ansible + Docker](#-method-2-vagrant--ansible--docker)

## 🏗️ Architecture & Topology

The project is structured as a **Monorepo** containing three main directories: `frontend`, `backend`, and `devops`. The infrastructure is automatically provisioned into three separate Virtual Machines:

| Service | IP Address | Port | Technology Stack |
| :--- | :--- | :--- | :--- |
| **Frontend** | `192.168.56.10` | `3000` | React, Vite, Nginx|
| **Backend API** | `192.168.56.11` | `8080` | Node.js, Express, PM2 |
| **Database** | `192.168.56.12` | `27017` | MongoDB |

---

## 🛠️ Prerequisites

Before deploying the infrastructure, ensure you have the following installed on your host machine:
* **VirtualBox** (Hypervisor)
* **Vagrant** (VM Orchestration)
* **Ansible** (Configuration Management)

---
## 💻 Method 1: Vagrant + Ansible (Without Docker)

## 🚀 First-Time Deployment

To provision the infrastructure from scratch, navigate to the root directory (where your `Vagrantfile` is located) and run the following commands:

1. **Boot the VMs:**
   ```bash
   vagrant up
2. **Configure VMs with Ansible playbooks**
   ```bash
   ansible-playbook -i devops/Configuration\ Management/ansible/inventories/local/hosts.ini devops/Configuration\ Management/ansible/site.yml --ask-vault-pass

## 🚀 Deployment After VMs Recreation

1. **Move to folder**
   ```bash
   cd devops/Infrastructure/without_docker
2. **Boot the VMs:**
   ```bash
   vagrant up
3. **Deleting old ssh connections**
   ```bash
   ssh-keygen -f "/home/redict/.ssh/known_hosts" -R "192.168.56.10"
   ssh-keygen -f "/home/redict/.ssh/known_hosts" -R "192.168.56.11"
   ssh-keygen -f "/home/redict/.ssh/known_hosts" -R "192.168.56.12"
4. **Setting right permissions**
   ```bash
   chmod 600 devops/Infrastructure/without_docker/.vagrant/machines/database/virtualbox/private_key
   chmod 600 devops/Infrastructure/without_docker/.vagrant/machines/frontend/virtualbox/private_key
   chmod 600 devops/Infrastructure/without_docker/.vagrant/machines/backend/virtualbox/private_key
5. **Configure VMs with Ansible playbooks**
   ```bash
   ansible-playbook -i devops/Configuration\ Management/ansible/inventories/local/hosts.ini devops/Configuration\ Management/ansible/site.yml --ask-vault-pass

---
## 🐳 Method 2: Vagrant + Ansible + Docker

# 🚀 Automated Deployment
1. **Move to folder**
   ```bash
   cd devops/Infrastructure/with_docker
2. **Boot and Provision:**
   ```bash
# 🚀 Space2Study — Cloud Infrastructure (Terraform + AWS ECS)

> This branch demonstrates the **cloud infrastructure stage**: AWS resources provisioned with Terraform, running the app on ECS Fargate behind an Application Load Balancer. This was later superseded by a self-managed Kubernetes stack on the [`k8s`](../../tree/k8s) branch — see the [main branch README](../../tree/main) for how this fits into the overall evolution.

## 🏗️ Architecture & Topology

| Component | AWS Service | Notes |
| :--- | :--- | :--- |
| **Frontend** | ECS Fargate service | Served behind the ALB |
| **Backend API** | ECS Fargate service | Node.js/Express + GraphQL |
| **Database** | MongoDB on ECS Fargate + EFS | Self-managed Mongo, *not* Amazon DocumentDB — see note below |
| **Container Registry** | ECR | One repository per service |
| **Networking** | VPC, public + private subnets | NAT gateway for private-subnet egress |
| **Load Balancing** | Application Load Balancer (ALB) | Routes to frontend/backend target groups |
| **Secrets** | AWS Secrets Manager | Injected into ECS task definitions |

> **Naming note:** the Terraform module historically called `documentdb` does **not** provision Amazon DocumentDB — it provisions self-managed MongoDB running as an ECS Fargate task with an EFS-backed volume for persistence. Treat it as self-managed Mongo when reasoning about backups, failover, or cost.

## 🛠️ Prerequisites

* **Terraform** (matching the version pinned in `devops/infrastructure/terraform/versions.tf`)
* **AWS CLI**, configured with credentials that can create VPC/ECS/ECR/IAM/Secrets Manager resources
* **Docker**, to build and push service images to ECR

## 🚀 Deployment

1. **Configure AWS credentials:**
   ```bash
   aws configure
   ```
2. **Initialize Terraform:**
   ```bash
   cd devops/infrastructure/terraform
   terraform init
   ```
3. **Review the plan before applying anything:**
   ```bash
   terraform plan
   ```
4. **Apply:**
   ```bash
   terraform apply
   ```
5. **Build and push service images:**
   ```bash
   aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.<your-region>.amazonaws.com
   docker build -t <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/space2study-backend:latest ./backend
   docker push <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/space2study-backend:latest
   ```
6. **Roll out via Jenkins**, or force a new ECS deployment directly:
   ```bash
   aws ecs update-service --cluster space2study --service backend --force-new-deployment
   ```

## 🩺 Troubleshooting & Known Limitations

This branch is kept as a reference implementation. A few things worth knowing before relying on it as-is:

| Symptom / Concern | Cause | Note |
| :--- | :--- | :--- |
| Scan results don't seem to block bad images | ECR repositories were configured with `MUTABLE` tag mutability | Set repositories to `IMMUTABLE` if you want the scan-then-deploy gate to actually hold |
| Checkov stage always shows green | The pipeline stage was declared in the Jenkinsfile but never actually invoked `checkov` | Verify the stage runs the scanner, don't trust a named-but-empty stage |
| Long-lived AWS credentials in every build | Jenkins pulled a static IAM user access key and a cluster-admin kubeconfig into each pipeline run | Prefer an instance profile or short-lived scoped credentials — see how `k8s` handles this with IAM instance profiles |
| Higher cost than expected | ALB, Fargate, and Secrets Manager are not AWS Free Tier eligible | Budget for these explicitly, or see the [`k8s`](../../tree/k8s) branch for a self-managed, lower-cost alternative |

For the full CI/CD and shift-left security toolchain shared across branches, see the [main branch README](../../tree/main).