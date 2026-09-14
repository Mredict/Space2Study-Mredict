# 🚀 Space2Study — Kubernetes Infrastructure (Self-Managed k3s + GitOps)

> This branch is the **current architecture**: a self-managed k3s cluster on EC2, provisioned with Terraform and operated through GitOps. It replaces the ECS Fargate + Secrets Manager setup on [`cloud`](https://github.com/Mredict/Space2Study-Mredict/tree/cloud) with a lower-cost stack redesigned to fit a fixed budget. See the [main branch README](https://github.com/Mredict/Space2Study-Mredict/tree/main) for how this fits into the overall evolution.

## 🏗️ Architecture & Topology

| Component | Detail |
| :--- | :--- |
| **Cluster** | k3s — 1 control-plane (`c7i-flex.large`) + 2 workers (`t3.small`), `eu-central-1` |
| **Provisioning** | Terraform — VPC, IAM instance profiles, security groups |
| **Container Registry** | Amazon ECR (credential provider installed on workers by `bootstrap-cluster-addons.sh`) |
| **CI** | Jenkins — builds, pushes to ECR, commits the new image tag to the values file |
| **GitOps** | ArgoCD — auto-syncs `values-dev.yaml` / `values-prod.yaml` into `space2study-dev` / `space2study-prod` |
| **Secrets** | External Secrets Operator, pulling from SSM Parameter Store |
| **Ingress / TLS** | ingress-nginx + cert-manager |
| **Policy enforcement** | Kyverno — non-root, no privilege escalation, mandatory resource limits on every manifest |
| **Database** | MongoDB StatefulSet, replica set with keyfile authentication |

## 🛠️ Prerequisites

* **Terraform**
* **AWS CLI**, configured with credentials that can create EC2/VPC/IAM resources
* **kubectl**, pointed at the cluster once it's up
* **Helm**
* **ArgoCD CLI** (optional, for manual sync/inspection)

## 🚀 Deployment

1. **Provision the cluster infrastructure:**
   ```bash
   cd devops/infrastructure/terraform
   terraform init
   terraform apply
   ```
   This creates the control-plane and worker EC2 instances, IAM instance profiles, and networking. k3s installs itself via the bootstrap user-data script.

2. **Pull the kubeconfig.**

   > ⚠️ **Note:** you cannot access the Kubernetes API with `kubectl` until a kubeconfig pointing at this cluster exists locally.

   ```bash
   cd devops
   ./scripts/get-kubeconfig.sh space2study <environment>

   # And verify
   kubectl get nodes
   ```

3. **Bootstrap cluster addons:**
   ```bash
   ./scripts/bootstrap-cluster-addons.sh
   ```

4. **Configure secrets on Jenkins.**

5. **Replace every placeholder before the first sync.** `values-dev.yaml` / `values-prod.yaml` ship with literal placeholders that must be set to real values:

   | Placeholder | Replace with |
   | :--- | :--- |
   | `AWS_ACCOUNT_ID` | Your actual 12-digit AWS account ID |
   | `<NODE_PUBLIC_IP>` (in `SERVER_URL`, `CLIENT_URL`, `COOKIE_DOMAIN`, `domain`) | Your worker's Elastic IP, via a [nip.io](https://nip.io) wildcard hostname (e.g. `203-0-113-10.nip.io`) for zero-config DNS |

## 📜 Scripts Reference

All scripts live in `devops/scripts/`.

### `get-kubeconfig.sh`

Fetches the k3s-generated kubeconfig from the control-plane node and makes it usable from your local machine. k3s writes its kubeconfig to `/etc/rancher/k3s/k3s.yaml` on the control-plane with the API server address set to `127.0.0.1`, which only works *on* that node — this script retrieves that file SSM and rewrites the server address to the control-plane's public/Elastic IP so `kubectl` on your machine can reach it. Run this once after `terraform apply`, and again any time the control-plane's address changes.

### `bootstrap-cluster-addons.sh`

Installs everything the cluster needs before the app can be deployed onto it — the pieces described in the architecture table above:

* The ECR credential provider binary + `CredentialProviderConfig` on every worker
* ArgoCD (for GitOps sync)
* ingress-nginx + cert-manager (ingress and TLS)
* Kyverno (policy enforcement)
* External Secrets Operator (pulls app secrets from SSM Parameter Store)

Run this once per fresh cluster, right after `get-kubeconfig.sh`. It's safe to re-run — each addon install is idempotent.

### `cluster-up.sh`

Brings a previously stopped cluster back online without a full Terraform re-apply. Starts the control-plane and worker EC2 instances, waits for k3s to report healthy, and re-runs `get-kubeconfig.sh` so your local kubectl context is current.

```bash
./scripts/cluster-up.sh
```

### `cluster-down.sh`

Stops the control-plane and worker EC2 instances (rather than destroying them) so you stop paying for compute while the cluster sits idle. Because the workers use Elastic IPs, addresses survive the stop/start cycle, which is what makes `cluster-up.sh` able to bring everything back without re-bootstrapping.

```bash
./scripts/cluster-down.sh
```

> If you actually want to tear the environment down completely (e.g. end of the course project), run `terraform destroy` from `devops/infrastructure/terraform` instead — `cluster-down.sh` is for pausing, not decommissioning.

## 🔍 Verifying & Maintaining the Infrastructure

**Cluster health**
```bash
kubectl get nodes -o wide
kubectl get pods -A
```

**GitOps status**
```bash
argocd app list
argocd app get space2study-dev
kubectl logs -n argocd deploy/argocd-application-controller
```

**Security & policy posture**
```bash
kubectl get clusterpolicies
kubectl get certificate -A
kubectl get externalsecret -A
```

**Application state**
```bash
kubectl get pods -n space2study-dev
kubectl logs -n space2study-dev deploy/backend
kubectl get statefulset -n space2study-dev
```

**Infrastructure drift**
```bash
cd devops/infrastructure/terraform
terraform plan     # should show no changes if the cluster matches Terraform state
```

For the full CI/CD and shift-left security toolchain shared across branches, see the [main branch README](https://github.com/Mredict/Space2Study-Mredict/tree/main).