#!/bin/bash
set -euxo pipefail

K3S_TOKEN=$(aws secretsmanager get-secret-value \
  --region "${aws_region}" \
  --secret-id "${token_secret_arn}" \
  --query SecretString --output text)

# ----------------------------------------------------------------------------
# Install k3s server
# ----------------------------------------------------------------------------
mkdir -p /etc/k3s
cat >/etc/k3s/audit-policy.yaml <<'AUDIT'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets", "configmaps"]
  - level: RequestResponse
    verbs: ["create", "update", "patch", "delete"]
    resources:
      - group: ""
        resources: ["pods/exec", "pods/attach"]
  - level: Metadata
    omitStages: ["RequestReceived"]
AUDIT

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${k3s_version}" \
  K3S_TOKEN="$K3S_TOKEN" \
  sh -s - server \
    --tls-san "${cluster_public_ip}" \
    --node-taint "node-role.kubernetes.io/control-plane:NoSchedule" \
    --disable traefik \
    --disable servicelb \
    --write-kubeconfig-mode 600 \
    --kube-apiserver-arg="audit-log-path=/var/log/k3s-audit.log" \
    --kube-apiserver-arg="audit-log-maxage=7" \
    --kube-apiserver-arg="audit-log-maxbackup=3" \
    --kube-apiserver-arg="audit-policy-file=/etc/k3s/audit-policy.yaml" \
    --default-local-storage-path /mnt/mongo-data/local-path-provisioner

# CloudWatch agent for node-level CPU/mem/disk metrics.
dnf install -y amazon-cloudwatch-agent || echo "WARNING: amazon-cloudwatch-agent install failed, continuing without it" >&2
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s -c default || true
