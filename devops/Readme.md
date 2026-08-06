# 🚀 Space2Study — Infrastructure as Code (IaaC)

This repository contains the complete infrastructure, backend, and frontend code for the **Space2Study** platform. The project utilizes a modern DevSecOps approach, deploying a fully isolated, 3-tier architecture locally using Vagrant and Ansible.

---

## 🏗️ Architecture & Topology

The project is structured as a **Monorepo** containing three main directories: `frontend`, `backend`, and `devops`. The infrastructure is automatically provisioned into three separate Virtual Machines:

| Service | IP Address | Port | Technology Stack |
| :--- | :--- | :--- | :--- |
| **Frontend** | `192.168.56.10` | `3000` | React, Vite, PM2 |
| **Backend API** | `192.168.56.11` | `8080` | Node.js, Express, PM2 |
| **Database** | `192.168.56.12` | `27017` | MongoDB |

---

## 🛠️ Prerequisites

Before deploying the infrastructure, ensure you have the following installed on your host machine:
* **VirtualBox** (Hypervisor)
* **Vagrant** (VM Orchestration)
* **Ansible** (Configuration Management)

---

## 🚀 First-Time Deployment

To provision the infrastructure from scratch, navigate to the root directory (where your `Vagrantfile` is located) and run the following commands:

1. **Boot and provision the Virtual Machines:**
   ```bash
   vagrant up