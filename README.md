# 🚀 Space2Study — DevSecOps Infrastructure Evolution

Space2Study is a full-stack study-matching platform (React/Vite frontend, Node.js/Express + GraphQL backend, MongoDB). This repository doubles as a **staged DevSecOps case study**: each branch is a self-contained checkpoint in the infrastructure's evolution, from manual bare-metal VMs to a GitOps-driven Kubernetes cluster on AWS.

> **Branch strategy:** these branches are checkpoints, not feature branches — they are not meant to be merged into one another. Check out the branch matching the stage you want to explore; each has its own README with full setup instructions.

## 📍 Branches

| Branch | Stage | What it demonstrates |
| :--- | :--- | :--- |
| [`local`](https://github.com/Mredict/Space2Study-Mredict/tree/local) | Local infrastructure | Vagrant + Ansible provisioning three VMs (with and without Docker), manual IaC, container hardening |
| [`cloud`](https://github.com/Mredict/Space2Study-Mredict/tree/cloud) | Cloud infrastructure | Terraform-provisioned AWS resources, ECR, Jenkins-driven deployment |
| [`k8s`](https://github.com/Mredict/Space2Study-Mredict/tree/k8s) | Kubernetes / GitOps | Self-managed k3s on EC2, Helm, ArgoCD, Kyverno policy enforcement, External Secrets Operator |

Each branch README covers: architecture and topology, prerequisites, and step-by-step deployment for that stage.

## 🏗️ Application Architecture

| Service | Technology Stack |
| :--- | :--- |
| **Frontend** | React, Vite, Nginx |
| **Backend API** | Node.js, Express, GraphQL, PM2 |
| **Database** | MongoDB |

## 🛠️ CI/CD & Security Toolchain

This project runs a shift-left pipeline in Jenkins, common across the `local` and `cloud`/`k8s` deployment targets:

| Stage | Tool |
| :--- | :--- |
| Lint | Hadolint, Ansible-lint |
| Secret scanning | Gitleaks |
| SAST | SonarQube |
| SCA | Snyk |
| Container image scanning | Trivy |
| Policy admission (k8s) | Kyverno |

See `sonar-project.properties` and `Jenkinsfile` at the root of this branch for the pipeline definition used against the application source.

## 📁 Repository Structure

```
.
├── backend/          # Node.js/Express + GraphQL API
├── frontend/         # React/Vite client
├── devops/           # Shared devops tooling for this branch
├── docs/             # Additional project documentation
├── docker-compose.yml
├── Jenkinsfile
└── sonar-project.properties
```

## 🚦 Getting Started

Pick the branch matching what you want to explore or deploy, then follow that branch's README:

```bash
git checkout local   # Vagrant + Ansible on VirtualBox
git checkout cloud   # Terraform on AWS
git checkout k8s     # Self-managed k3s + GitOps
```