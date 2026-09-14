# Space2Study: ECS Fargate -> self-managed k3s migration

## Architecture

```
              control-plane (c7i-flex.large, tainted NoSchedule -
              runs k3s server + SQLite only, no workload pods,
              no HA - single node by design; own Elastic IP
              for kubectl/API on :6443)
                        |
                (private IP, :6443)
                        |
        +---------------+---------------+
        |                               |
   worker-0 (t3.small)            worker-1 (t3.small)
   k3s agent, own Elastic IP      k3s agent, own Elastic IP
        |                               |
        +---------------+---------------+
                        |
         ingress-nginx (hostNetwork DaemonSet - runs on WORKERS
         only; reach the app at a worker's IP, NOT the
         control plane's)
                        |
        +---------------+---------------+
        |                               |
    frontend (2 pods)              backend (2-6 pods, HPA)
                                        |
                    mongodb-0 / mongodb-1 (StatefulSet, soft
                    anti-affinity - prefers one replica per
                    worker but can co-locate if it must -
                    local-path on a dedicated EBS volume per
                    worker, keyfile auth)

           (space2study-dev / space2study-prod namespaces - separate)

  Cross-cutting: cert-manager (self-signed), external-secrets (AWS Secrets
  Manager), Kyverno (policy enforcement, excludes infra namespaces),
  NetworkPolicies (default-deny), ResourceQuota/LimitRange, ArgoCD
  (in-cluster, pulls from git - see "CD: GitOps via ArgoCD" below; Jenkins
  builds/scans/pushes/signs images and commits the new tag to git, nothing
  more)
```

No NAT gateway/instance, no AWS load balancer, no EKS control plane, no SSH.
Node shell access is via SSM Session Manager only.

## What changed from the ECS design, and why

| Old (ECS Fargate) | New (k3s) | Why |
|---|---|---|
| `image_tag_mutability = MUTABLE` | `IMMUTABLE` | Mutable tags let a blessed, scanned image get silently swapped out later |
| Jenkins IAM user + static access key, unscoped, output from Terraform | Jenkins IAM user + static access key, but scoped to ECR push only (see "CI/CD identity" - IAM Roles Anywhere was attempted and hit an unresolved AWS-side issue) | Same credential type as before, but blast radius cut to one action instead of broad deploy/admin power |
| Self-signed cert as a **file committed to the repo** | cert-manager-issued cert, stored only as a k8s Secret | A private key should never be a file in git history |
| `recovery_window_in_days = 0` on Secrets Manager | 7 days | A destroy typo shouldn't be unrecoverable |
| Single Mongo container on EFS, no replication | 3-node Mongo replica set, one per node, keyfile auth | One task dying took the whole DB down before |
| No autoscaling | HPA on frontend + backend | Fixed `desired_count` doesn't respond to load |
| Health check matcher `200-399,404` | Real `/health` checks | Treating 404 as "healthy" hides real failures |
| No image signing, no SBOM, no policy gate | cosign signing, Syft SBOM, Kyverno enforce | Closes the "scanned but then what" gap |
| Jenkins runs `aws ecs update-service` directly against the cluster | Jenkins stops at build/scan/push; ArgoCD (in-cluster, pull-based) applies from git | Jenkins never holds a cluster credential at all; git becomes the audit trail for what's actually deployed |
| No budget alerting | AWS Budget at 50/80/100% of $100 | You said $100 total - this is non-negotiable |

## Cost reality (what you actually asked for)

Your account is on AWS's post-2025-07-15 **"Free Plan"**: a $100 signup
credit (up to $200 with earned activities), expiring after 6 months or when
it's used up, whichever comes first - not a card you're charged on, but a
real, finite balance that draws down exactly like real spend would, and the
account auto-closes (after a grace period) if it hits zero or the clock runs
out without you upgrading. Free-tier-eligible resources (t3.small is on that
list for this account type) unblock `RunInstances`, but "free-tier-eligible"
mostly just means AWS won't charge extra ON TOP of standard rates for that
resource type up to its own quota - it doesn't mean the credit isn't still
being consumed by everything else running. EBS storage in particular: the
free allowance is 30GB total: this design uses 3x (20GB root + 15GB mongo
data) = 105GB of gp3, so storage draws from your credit regardless of the
instance-type change.

Everything below assumes **3x t3.small** nodes (1 control-plane + 2 workers), eu-central-1, on-demand - the role split doesn't change the node/EIP count or the cost:

| Item | Running 24/7 | Stopped (study-session pattern) |
|---|---|---|
| 3x t3.small compute | ~$51/month | $0 |
| 3x gp3 root volumes (20GB) + 3x mongo data volumes (15GB) | ~$8/month | ~$8/month (storage bills regardless of power state) |
| 3x Elastic IPs | ~$11/month | ~$11/month (AWS bills all public IPv4 addresses per hour since Feb 2024, running or not) |
| **Total** | **~$70/month** | **~$19/month baseline + only the hours you're actually running** |

Running this 24/7 would still burn through your $100 credit in well under
two months. The `scripts/cluster-up.sh` / `cluster-down.sh` pair is how you
actually stay inside it: stop the nodes between study sessions, and you're
paying ~$19/month baseline plus only the compute hours you actually use. The
AWS Budget (50/80/100% of $100) will email/Discord-alert you well before
you're in trouble either way - but on the Free Plan, running out doesn't
just mean a bill, it means the account itself can close, so don't treat
those alerts as optional background noise.

If you want to cut the baseline further later: dropping to 1 node (no HA)
removes 2 of the 3 EIPs/volumes/instances and cuts the always-on cost to
roughly a third - worth doing if the HA learning goal is satisfied and you
want more runway.

## CI toolchain on the agent

Your `agent_setup` role (as shared) installs Docker, Node/npm, Snyk,
ansible-lint, hadolint, and gitleaks - but not `trivy`, `cosign`, `syft`,
`kyverno` CLI, `helm`, or `kubectl`, all of which the `Jenkinsfile` calls
directly. `ansible-addon/roles/ci_tools/` installs and version-checks all
six, pinned (not tracking `latest`), each verified against the project's
actual release page rather than guessed:

| Tool | Pinned version | Note |
|---|---|---|
| trivy | 0.74.0 | |
| cosign | 2.6.5 | Deliberately v2, not v3 (current latest) - v3 changed the default signature bundle format; not validated against this pipeline yet |
| syft | 1.51.1 | |
| kyverno CLI | 1.17.0 | |
| kubectl | 1.31.4 | Matches the pinned k3s server version |
| helm | 3.21.1 | Deliberately v3, not v4 (current stable since Nov 2025) - v4 is a breaking major version; **v3 only gets security fixes until 2026-11-11**, so this needs a deliberate, tested migration before then, not an indefinite deferral |

Merge `ci_tools` into your `agent.yml`'s `roles:` list (see
`ansible-addon/agent.yml.example`) - it's the only role that needs adding now
that Jenkins uses a plain static IAM credential instead of Roles Anywhere
(see below), which needed no VM-side role at all.

## CI/CD identity: Jenkins on Vagrant VMs

Your Jenkins controller (`192.168.56.10`) and agent (`192.168.56.15`) are
VirtualBox VMs, not EC2 instances, so there's no instance profile to attach
for AWS auth. **IAM Roles Anywhere was built and fully wired up here first** -
a self-managed CA, a properly-extended client certificate (verified correct:
basicConstraints, keyUsage, extendedKeyUsage, SHA256 signing, key/cert
correspondence, ARN consistency across trust anchor/profile/role, no
duplicate trust anchors, everything enabled) - and it still failed
`CreateSession` with `AccessDeniedException: Untrusted certificate.
Insufficient certificate` for reasons that didn't match any documented AWS
requirement after exhaustive checking. Diagnosing further would need
CloudTrail data-event visibility or an AWS Support case, neither of which
fit this project's scope, so this fell back to a **plain static IAM user**
scoped to exactly the same narrow ECR-push permissions the Roles Anywhere
role would have had.

The upside of the fallback: static credentials need **no provisioning on
either VM at all**. The access key/secret live only in Jenkins' own
credential store and get injected per-build via `withCredentials` in the
`Jenkinsfile`, scoped to just the one stage that needs them.

Both VMs reach AWS through the default NAT adapter Vagrant attaches (the
`private_network` adapter at `192.168.56.x` is host-only, VM-to-VM/host
only) - so to AWS, both the controller and the agent appear to come from
your home public IP, same as your own laptop. One entry in
`api_server_allowed_cidrs` covers all of it.

**One-time setup:**

```bash
cd terraform-k3s
terraform apply   # creates the scoped IAM user + access key

terraform output jenkins_access_key_id
terraform output -raw jenkins_secret_access_key
```

Then in Jenkins: **Manage Jenkins > Credentials**, add a new credential of
kind **"Username and password"**, ID `jenkins-aws-static-creds`, username =
the access key ID, password = the secret access key. That's the whole setup
- no Ansible role, no PKI, no `vagrant provision` needed for this part.

**Rotate this periodically** - it's a real long-lived credential, unlike
what Roles Anywhere would have given you. `terraform apply
-replace=module.iam.aws_iam_access_key.jenkins_static` generates a fresh
key pair; update the Jenkins credential with the new values afterward.

The Roles Anywhere tooling (`scripts/generate-jenkins-ca.sh`,
`scripts/render-agent-aws-vars.sh`, `ansible-addon/roles/aws_rolesanywhere_agent/`)
is still in this repo, marked as parked in each file - worth revisiting if
you ever get AWS Support access to see server-side why `CreateSession`
rejected an otherwise fully-correct certificate.

One thing I noticed but didn't touch: `docker_setup` configures
`192.168.56.15:5000` as an insecure registry on the agent - that's not
reachable from AWS (host-only network), so it can't be part of the k3s
deployment path. I've assumed it's for something else (a local build
cache/test loop) and left the pipeline pushing to ECR as the thing the k3s
nodes can actually pull from. Let me know if you want it wired into the
pipeline for something specific.

## CD: GitOps via ArgoCD, not Jenkins

Jenkins' job ends at "build, scan, sign, push, and propose" - it never
touches the cluster or holds a cluster credential. ArgoCD runs inside the
cluster and pulls: it watches this git repo, and applies whatever
`devops/helm/space2study` + the relevant `values-<env>.yaml` say should be
running.

Since ECR is immutable-tagged, every build gets a genuinely new tag, and
ArgoCD only reacts to *git* changes - so Jenkins's last stage
("Update GitOps Manifest") writes that new tag into `values-<env>.yaml` and
pushes the commit. That's the full extent of what Jenkins does toward
deployment now: one `sed` + `git push`, using a **new credential**
(`jenkins-git-push-creds`, a GitHub PAT with push access to this repo -
create it in Jenkins the same way as the other credentials) that replaces
the `k3s-kubeconfig` credential Jenkins used to need.

**Dev auto-syncs.** `cluster-addons/argocd-apps/dev-application.yaml` has
`syncPolicy.automated` set, so ArgoCD applies a new dev commit within its
default ~3-minute polling window, no action needed.

**Prod requires a manual sync** - deliberately no `automated` block on
`prod-application.yaml`. Jenkins still proposes the change by pushing the
commit, but nothing happens to the cluster until someone runs:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
argocd login localhost:8080 --username admin \
  --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
argocd app sync prod-space2study
```
That manual step **is** the approval gate now - it replaces the `input`
step that used to live in the Jenkinsfile.

**Before applying either Application manifest**, edit `repoURL` in both
files under `cluster-addons/argocd-apps/` - they currently point at
`https://github.com/Mredict/Space2Study-Mredict.git` with
`path: devops/helm/space2study`, which may not match wherever the chart
actually ends up living in your repo layout (it's moved before). If this
repo is private, ArgoCD also needs its own **read** credential configured
(`argocd repo add` or a repository Secret) - separate from Jenkins's
**write** credential above; a public repo needs neither.

**Capacity note, not a hypothetical one:** dev and prod now deploy to
separate namespaces (`space2study-dev` / `space2study-prod`) specifically so
they don't collide - but each one runs its own 3-node MongoDB replica set
plus frontend/backend pods. Running both at once on this same 3-node,
2GB-per-node cluster will very likely exceed available memory. Sync prod to
see it work once if you want, but don't expect to run both continuously
without adding capacity.

## Runbook

```bash
cd terraform-k3s
cp terraform.tfvars.example terraform.tfvars   # fill in real values
terraform init
terraform apply

./scripts/get-kubeconfig.sh space2study dev
export KUBECONFIG=$(pwd)/kubeconfig-dev.yaml
kubectl get nodes                               # should show 3 Ready nodes

./scripts/bootstrap-cluster-addons.sh           # ingress-nginx, cert-manager, external-secrets, kyverno, ArgoCD

# From here, deployment happens via Jenkins -> git -> ArgoCD (see "CD: GitOps
# via ArgoCD" above), not by running helm directly. To see it work once
# without a full Jenkins run: hand-edit values-dev.yaml's image tags to a
# real tag already in ECR, commit, push, and watch ArgoCD pick it up:
#   kubectl get application dev-space2study -n argocd -w

kubectl -n space2study-dev exec -it mongodb-0 -- mongosh --eval "rs.status()"   # verify replica set
curl -k https://$(terraform -chdir=terraform-k3s output -raw primary_worker_public_ip)/api/health   # a WORKER IP, not k3s_api_endpoint - that's the control plane, which runs no app pods

# End of study session:
./scripts/cluster-down.sh space2study dev
```

## Honest caveats - things to verify, not assume

- **MongoDB replica-set bootstrap** (`mongodb-replicaset-init-job.yaml`) follows
  the documented pattern for the official `mongo` image, but I couldn't run
  it against a live cluster. After the first deploy, check
  `kubectl exec mongodb-0 -n space2study-dev -- mongosh --eval "rs.status()"` -
  if the job's wait loop times out before DNS/networking is ready, widen the
  retry loop rather than assuming something else is broken.
- **`/health` and `/api/health` endpoints** are assumed to exist on the
  backend (used by the readiness/liveness probes and the Jenkins smoke test).
  If your app doesn't have one yet, add a cheap one - liveness probes that
  hit `/` can't tell "serving stale garbage" from "actually fine", which was
  the old health-check bug we're trying to leave behind.
- **External Secrets Operator uses a scoped static IAM credential**, not the
  node's instance role - deliberately, since the node role's IMDS access is
  blocked for pods (see `modules/iam/main.tf` comments for the full
  reasoning). This is a real long-lived credential, just a narrowly-scoped
  one. The textbook-correct fix is OIDC federation for k3s itself
  (`--service-account-issuer` + a registered AWS OIDC provider), which gets
  you real per-ServiceAccount IAM roles with no static keys at all - it's a
  good follow-up project once the basics are running and stable.
- **No domain name** means the self-signed cert-manager cert will always show
  a browser trust warning - expected, not a bug. The day you register a
  domain, swap `cluster-addons/cert-manager-cluster-issuer.yaml` for a Let's
  Encrypt ACME issuer and set `domain:` in `values.yaml`; nothing else in the
  chart needs to change.
- **Kyverno policies exclude infra namespaces** (`kube-system`,
  `ingress-nginx`, `cert-manager`, `external-secrets`, `kyverno`, `argocd`) -
  added after discovering the hard way that cluster-wide "Enforce" policies
  also apply to third-party charts' own internal jobs (ingress-nginx's
  admission-webhook setup job doesn't set explicit `runAsNonRoot`/resource
  limits, and got blocked on every Helm upgrade, not just first install).
  The policies still fully enforce against `space2study-dev`/`-prod` -
  only infra namespaces are exempted.
- **ArgoCD's `podSecurityContext` keys** in `cluster-addons/argocd-values.yaml`
  are my best attempt at matching the argo-helm chart's actual schema for
  version 10.8.1, added specifically so Kyverno's `require-non-root` policy
  doesn't reject ArgoCD's own pods - but I couldn't verify the exact value
  paths against a live chart. If ArgoCD pods don't come up after
  `bootstrap-cluster-addons.sh`, run `kubectl describe pod -n argocd <pod>`
  first - a Kyverno admission rejection there means these keys need
  adjusting; check the real schema with
  `helm show values argo/argo-cd --version 10.8.1`.
- **The GitOps tag-update `sed` commands** in the Jenkinsfile's "Update
  GitOps Manifest" stage rely on exact YAML structure (top-level
  `frontend:`/`backend:` blocks, in that order) rather than actually parsing
  YAML - they'll work for the current file layout but are fragile against
  restructuring. `yq` would be the robust fix; not added to `ci_tools` to
  keep this change scoped, but worth doing if you reorganize the values
  files later.
- **MongoDB dropped from 3 replicas to 2** when the cluster moved to 1
  control-plane + 2 workers - there's only 2 nodes to put data-bearing
  replicas on now. Anti-affinity was also softened from hard to soft
  (`preferredDuringSchedulingIgnoredDuringExecution`) so a StatefulSet
  scheduling mismatch never hard-fails. A 2-member replica set has weaker
  failover characteristics than 3 - proper odd-numbered quorum would mean
  adding a lightweight MongoDB **arbiter** (votes but holds no data) running
  on the otherwise-idle, tainted control-plane node, which needs an explicit
  toleration + nodeSelector to land there. Worth doing as a deliberate
  follow-up; not folded into this change to keep it scoped.
- **No control-plane HA anymore** - a single control-plane node is a single
  point of failure for the API server (though the workers keep serving
  existing traffic uninterrupted if it's briefly down). This was a
  deliberate trade for resource isolation after etcd started timing out
  sharing nodes with workloads - see the Architecture section.
- **Jenkins uses a static IAM access key**, not IAM Roles Anywhere - a
  deliberate fallback after Roles Anywhere was built and verified correct
  end-to-end but hit an unresolved AWS-side certificate rejection (see
  "CI/CD identity" above for the full story). Rotate this credential
  periodically - unlike what Roles Anywhere would have provided, it doesn't
  expire on its own.
- I could not run `terraform validate`/`plan` or `helm template` against a
  live backend in this environment - I've been careful with the HCL/YAML but
  treat the first `terraform plan` as the real first test, not a formality.

## Next steps worth asking me for
- OIDC federation for k3s (removes the last static credential)
- Prometheus/Grafana (kube-prometheus-stack) wired to the same Discord webhook
- A real domain + Let's Encrypt once you have one
- Velero for scheduled EBS snapshot backups of the Mongo data volumes
