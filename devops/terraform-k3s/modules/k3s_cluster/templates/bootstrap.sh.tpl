#!/bin/bash
set -euxo pipefail

# ----------------------------------------------------------------------------
# 0. Mount the dedicated MongoDB data volume (separate from root disk)
# ----------------------------------------------------------------------------
DEVICE="${mongo_device_name}"
MOUNT_POINT="/mnt/mongo-data"
mkdir -p "$MOUNT_POINT"
# nvme-backed instances expose EBS volumes as /dev/nvme*, not /dev/xvdf -
# resolve the real device before formatting. This retries for up to 60s:
# the aws_volume_attachment happens via a separate API call from instance
# launch, and user_data can start running before the OS has actually
# enumerated the newly attached block device - a real race, not a
# hypothetical one. Failing on the first check (as this used to) means the
# ENTIRE bootstrap script aborts here (set -e) before k3s ever gets
# installed, which looks like "k3s never came up" with no obvious cause.
REAL_DEVICE=""
for i in $(seq 1 20); do
  if [ -e "$DEVICE" ]; then
    REAL_DEVICE=$(readlink -f "$DEVICE")
    break
  fi
  for nvme in /dev/nvme*n1; do
    [ -e "$nvme" ] || continue
    if [ "$nvme" != "/dev/nvme0n1" ] && ! mount | grep -q "^$nvme "; then
      REAL_DEVICE="$nvme"
      break 2
    fi
  done
  echo "Mongo data device not visible yet, waiting (attempt $i/20)..."
  sleep 3
done
[ -n "$REAL_DEVICE" ] || { echo "Could not resolve mongo data device" >&2; exit 1; }
if ! blkid "$REAL_DEVICE" >/dev/null 2>&1; then
  mkfs.ext4 -F "$REAL_DEVICE"
fi
mount "$REAL_DEVICE" "$MOUNT_POINT" || true
echo "$REAL_DEVICE $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
mkdir -p "$MOUNT_POINT/local-path-provisioner"

# ----------------------------------------------------------------------------
# 1. Harden the instance metadata service against pod-level access
# ----------------------------------------------------------------------------
# k3s's pod network (flannel, default 10.42.0.0/16) is separate from the host.
# Block traffic FROM the pod CIDR TO the IMDS address so a compromised pod
# cannot reach 169.254.169.254 and inherit this node's IAM role, even though
# hop-limit=1 on the instance already makes this hard from inside a container.
#
# AL2023's standard AMI defaults to nftables and does not ship the
# standalone `iptables` binary - install it explicitly (it provides an
# nftables-backed compatibility CLI) rather than assume it's present.
dnf install -y iptables

cat >/etc/systemd/system/imds-pod-block.service <<'UNIT'
[Unit]
Description=Block pod network access to EC2 IMDS
After=network.target
Before=k3s.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/iptables -I FORWARD -s 10.42.0.0/16 -d 169.254.169.254 -j DROP
ExecStart=/usr/sbin/iptables -I OUTPUT -s 10.42.0.0/16 -d 169.254.169.254 -j DROP

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
# This is defense-in-depth hardening, not something k3s itself depends on to
# function - it must never be able to take the whole node down if it fails
# for some environment-specific reason I didn't anticipate. Warn loudly and
# continue rather than letting `set -e` abort the entire bootstrap here,
# which is exactly what happened before this was made non-fatal: the actual
# k3s install a few lines below never even ran.
systemctl enable --now imds-pod-block.service || {
  echo "WARNING: imds-pod-block.service failed to start - pod-level IMDS access is NOT blocked on this node." >&2
  echo "Continuing with k3s install regardless; fix this separately (see modules/iam comments on why it matters)." >&2
}

# ----------------------------------------------------------------------------
# 2. Fetch the cluster join token from Secrets Manager (never baked into
#    user_data as plaintext, never typed by a human)
# ----------------------------------------------------------------------------
K3S_TOKEN=$(aws secretsmanager get-secret-value \
  --region "${aws_region}" \
  --secret-id "${token_secret_arn}" \
  --query SecretString --output text)

# ----------------------------------------------------------------------------
# 3. Install k3s (version pinned, traefik/servicelb disabled - we run
#    ingress-nginx + our own LB story instead), audit logging enabled
# ----------------------------------------------------------------------------
mkdir -p /etc/k3s
cat >/etc/k3s/audit-policy.yaml <<'AUDIT'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
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

%{ if is_init ~}
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${k3s_version}" \
  K3S_TOKEN="$K3S_TOKEN" \
  sh -s - server \
    --cluster-init \
    --tls-san "${cluster_public_ip}" \
    --disable traefik \
    --disable servicelb \
    --write-kubeconfig-mode 600 \
    --kube-apiserver-arg="audit-log-path=/var/log/k3s-audit.log" \
    --kube-apiserver-arg="audit-log-maxage=7" \
    --kube-apiserver-arg="audit-log-maxbackup=3" \
    --kube-apiserver-arg="audit-policy-file=/etc/k3s/audit-policy.yaml" \
    --default-local-storage-path "$MOUNT_POINT/local-path-provisioner"
%{ else ~}
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="${k3s_version}" \
  K3S_TOKEN="$K3S_TOKEN" \
  sh -s - server \
    --server "https://${server_private_ip}:6443" \
    --tls-san "${cluster_public_ip}" \
    --disable traefik \
    --disable servicelb \
    --write-kubeconfig-mode 600 \
    --kube-apiserver-arg="audit-log-path=/var/log/k3s-audit.log" \
    --kube-apiserver-arg="audit-log-maxage=7" \
    --kube-apiserver-arg="audit-log-maxbackup=3" \
    --kube-apiserver-arg="audit-policy-file=/etc/k3s/audit-policy.yaml" \
    --default-local-storage-path "$MOUNT_POINT/local-path-provisioner"
%{ endif ~}

# CloudWatch agent for node-level CPU/mem/disk metrics feeding the existing
# budget + alarm pipeline. Same non-fatal treatment as the IMDS block above -
# monitoring should never be able to fail a node's bootstrap after k3s
# itself is already up and working.
dnf install -y amazon-cloudwatch-agent || echo "WARNING: amazon-cloudwatch-agent install failed, continuing without it" >&2
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s -c default || true
