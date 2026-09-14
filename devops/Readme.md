# 🚀 Space2Study — Kubernetes Infrastructure (Self-Managed k3s + GitOps)

> This branch is the **current architecture**: a self-managed k3s cluster on EC2, provisioned with Terraform and operated through GitOps. It replaces the ECS Fargate + Secrets Manager setup on [`cloud`](../../tree/cloud) with a lower-cost stack redesigned to fit a fixed budget. See the [main branch README](../../tree/main) for how this fits into the overall evolution.

## 🏗️ Architecture & Topology

| Component | Detail |
| :--- | :--- |
| **Cluster** | k3s — 1 control-plane (`c7i-flex.large`) + 2 workers (`t3.small`), `eu-central-1` |
| **Provisioning** | Terraform — VPC, IAM instance profiles, security groups |
| **Container Registry** | Amazon ECR (see note on the credential provider below) |
| **CI** | Jenkins — builds, pushes to ECR, commits the new image tag to the values file |
| **GitOps** | ArgoCD — auto-syncs `values-dev.yaml` / `values-prod.yaml` into `space2study-dev` / `space2study-prod` |
| **Secrets** | External Secrets Operator, pulling from SSM Parameter Store |
| **Ingress / TLS** | ingress-nginx + cert-manager (Let's Encrypt) |
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
   This creates the control-plane and worker EC2 instances, IAM instance profiles, and networking. k3s installs itself via the bootstrap user-data script — confirm the cluster is up with:
   ```bash
   kubectl get nodes
   ```

2. **Install the ECR credential provider on every worker.**

   > ⚠️ **Note:** k3s does **not** bundle an ECR credential provider the way EKS does. Without this step, every image pull fails with `no basic auth credentials`, even with correct IAM permissions.

   ```bash
   # on each worker node
   sudo mkdir -p /var/lib/rancher/credentialprovider/bin/
   sudo cp ecr-credential-provider /var/lib/rancher/credentialprovider/bin/
   # write CredentialProviderConfig with kind: CredentialProviderConfig
   # and apiVersion: kubelet.config.k8s.io/v1 — both fields are required
   sudo systemctl restart k3s-agent
   ```

3. **Bootstrap ArgoCD** and point it at this repository's GitOps path:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

4. **Configure secrets.** Set up the External Secrets Operator and confirm your SSM Parameter Store entries exist for the values the app expects.

5. **Replace every placeholder before the first sync.** `values-dev.yaml` / `values-prod.yaml` ship with literal placeholders that must be set to real values:

   | Placeholder | Replace with |
   | :--- | :--- |
   | `AWS_ACCOUNT_ID` | Your actual 12-digit AWS account ID |
   | `<NODE_PUBLIC_IP>` (in `SERVER_URL`, `CLIENT_URL`, `COOKIE_DOMAIN`, `domain`) | Your worker's Elastic IP, via a [nip.io](https://nip.io) wildcard hostname (e.g. `203-0-113-10.nip.io`) for zero-config DNS |

6. **Let ArgoCD sync**, then verify:
   ```bash
   kubectl get pods -n space2study-dev
   argocd app get space2study-dev
   ```

## 🩺 Troubleshooting

Real issues hit while standing this cluster up — worth checking first if something doesn't come up clean:

| Symptom | Cause | Fix |
| :--- | :--- | :--- |
| Jenkins GitOps push rejected (non-fast-forward) | Pipeline hardcoded `HEAD:main` instead of the actual target branch | `git fetch` + `checkout -B` before committing the new image tag |
| ArgoCD silently stops refreshing | `argocd-application-controller` OOM-killed against a 384Mi limit | Raise the controller memory limit (768Mi worked here) |
| Kyverno blocks a Deployment | Container `securityContext` missing explicit `privileged: false` / `runAsNonRoot: true` | Set both fields explicitly — Kyverno won't infer defaults |
| Image pulls fail with `no basic auth credentials` | k3s doesn't bundle an ECR credential provider like EKS | Install `ecr-credential-provider` + `CredentialProviderConfig` on every worker (see Step 2) |
| Image pull `not found` for a tag that should exist | ECR lifecycle policy expired the image faster than expected — Cosign signature artifacts were consuming rotation slots | Account for signature artifacts when sizing lifecycle policy retention |
| MongoDB replica set never forms | `mongod` rejects a group-readable keyfile; the Secret volume mounts with `fsGroup` permissions | Use an init container to copy the keyfile into an `emptyDir` and `chmod 600` it |
| MongoDB StatefulSet update won't apply | Missing `timeoutSeconds` on liveness/readiness probes (default 1s is too short for `mongosh` startup on `t3.small`); ArgoCD's sync gets stuck on a locked `operationState` | Set explicit probe timeouts; use ArgoCD's **Replace** sync option to break the stuck lock |
| Init Job never runs | Kyverno's `require-resource-limits` policy blocks a Job with no `resources:` block or labels | Add resource limits and labels to the Job spec, then `kubectl apply` directly — ArgoCD's hook mechanism won't re-fire automatically on an already-synced app |
| Readiness probe floods logs with 404s | No `/health` route defined in the Express app | Add `app.get('/health', ...)` before the catch-all error handler |
| Email confirmation fails (`EMAIL_NOT_SENT`) | A swallowed error in `createTransport`'s catch block | Rethrow instead of just logging |
| Email confirmation fails with `invalid_grant` | OAuth2 refresh token expired — Google enforces a 7-day expiry for apps in Testing consent mode | Move the OAuth consent screen out of Testing mode, or refresh the token within the window |
| Email confirmation fails with `ECONNREFUSED` on port 465 | Egress `NetworkPolicy` only allowed ports 443/587; `nodemailer`'s `secure: true` Gmail preset defaults to SMTPS on 465 | Add port 465 to the egress policy |

For the full CI/CD and shift-left security toolchain shared across branches, see the [main branch README](../../tree/main).