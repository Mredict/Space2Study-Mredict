# 🚀 Space2Study — Cloud Infrastructure (Terraform + AWS ECS)

> This branch demonstrates the **cloud infrastructure stage**: AWS resources provisioned with Terraform, running the app on ECS Fargate behind an Application Load Balancer. This was later superseded by a self-managed Kubernetes stack on the [`k8s`](https://github.com/Mredict/Space2Study-Mredict/tree/k8s) branch — see the [main branch README](https://github.com/Mredict/Space2Study-Mredict/tree/main) for how this fits into the overall evolution.

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

For the full CI/CD and shift-left security toolchain shared across branches, see the [main branch README](https://github.com/Mredict/Space2Study-Mredict/tree/main).