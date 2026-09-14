# 🚀 Space2Study — Local Infrastructure (Vagrant + Ansible)

> This branch demonstrates the **local infrastructure stage**: three VirtualBox VMs provisioned with Vagrant and configured with Ansible. See the [main branch README](https://github.com/Mredict/Space2Study-Mredict/tree/main) for how this fits into the overall DevSecOps evolution.

## 📌 Deployment Methods

* [Method 1: Vagrant + Ansible (Without Docker)](#-method-1-vagrant--ansible-without-docker)
* [Method 2: Vagrant + Ansible + Docker](#-method-2-vagrant--ansible--docker)

## 🏗️ Architecture & Topology

The project is structured as a **monorepo** containing three main directories: `frontend`, `backend`, and `devops`. Infrastructure is automatically provisioned into three separate virtual machines:

| Service | IP Address | Port | Technology Stack |
| :--- | :--- | :--- | :--- |
| **Frontend** | `192.168.56.10` | `3000` | React, Vite, Nginx |
| **Backend API** | `192.168.56.11` | `8080` | Node.js, Express, PM2 |
| **Database** | `192.168.56.12` | `27017` | MongoDB |

## 🛠️ Prerequisites

Before deploying the infrastructure, make sure you have the following installed on your host machine:

* **VirtualBox** (hypervisor)
* **Vagrant** (VM orchestration)
* **Ansible** (configuration management)

---

## 💻 Method 1: Vagrant + Ansible (Without Docker)

### 🚀 First-Time Deployment

From the repository root (where the `Vagrantfile` lives):

1. **Boot the VMs:**
   ```bash
   vagrant up
   ```
2. **Configure the VMs with Ansible:**
   ```bash
   ansible-playbook \
     -i devops/configuration-management/ansible/inventories/local/hosts.ini \
     devops/configuration-management/ansible/site.yml \
     --ask-vault-pass
   ```

### 🔁 Redeploying After VM Recreation

1. **Move into the infrastructure folder:**
   ```bash
   cd devops/infrastructure/without-docker
   ```
2. **Boot the VMs:**
   ```bash
   vagrant up
   ```
3. **Clear stale SSH host keys.**

   > ⚠️ **Note:** this removes any existing known_hosts entries for these IPs. Only run this if you're re-provisioning the same lab VMs — don't run it against IPs you don't control.

   ```bash
   ssh-keygen -f ~/.ssh/known_hosts -R "192.168.56.10"
   ssh-keygen -f ~/.ssh/known_hosts -R "192.168.56.11"
   ssh-keygen -f ~/.ssh/known_hosts -R "192.168.56.12"
   ```
4. **Set correct key permissions:**
   ```bash
   chmod 600 devops/infrastructure/without-docker/.vagrant/machines/database/virtualbox/private_key
   chmod 600 devops/infrastructure/without-docker/.vagrant/machines/frontend/virtualbox/private_key
   chmod 600 devops/infrastructure/without-docker/.vagrant/machines/backend/virtualbox/private_key
   ```
5. **Configure the VMs with Ansible:**
   ```bash
   ansible-playbook \
     -i devops/configuration-management/ansible/inventories/local/hosts.ini \
     devops/configuration-management/ansible/site.yml \
     --ask-vault-pass
   ```

---

## 🐳 Method 2: Vagrant + Ansible + Docker

### 🚀 Automated Deployment

1. **Move into the infrastructure folder:**
   ```bash
   cd devops/infrastructure/with-docker
   ```
2. **Boot and provision:**
   ```bash
   vagrant up
   ```

See the [main branch README](https://github.com/Mredict/Space2Study-Mredict/tree/main) for the full CI/CD and security toolchain shared across all deployment stages.