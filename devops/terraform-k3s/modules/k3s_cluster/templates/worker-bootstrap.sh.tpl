#!/bin/bash
set -euxo pipefail

# ----------------------------------------------------------------------------
# 0. Mount the dedicated MongoDB data volume
# ----------------------------------------------------------------------------
DEVICE="${mongo_device_name}"
MOUNT_POINT="/mnt/mongo-data"
mkdir -p "$MOUNT_POINT"


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
# 1. Harden the instance
# ----------------------------------------------------------------------------
cat >/etc/systemd/system/imds-pod-block.service <<'UNIT'
[Unit]
Description=Block pod network access to EC2 IMDS
After=network.target
Before=k3s-agent.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/iptables -I FORWARD -s 10.42.0.0/16 -d 169.254.169.254 -j DROP
ExecStart=/usr/sbin/iptables -I OUTPUT -s 10.42.0.0/16 -d 169.254.169.254 -j DROP

[Install]
WantedBy=multi-user.target
UNIT

dnf install -y iptables

systemctl daemon-reload
systemctl enable --now imds-pod-block.service || {
  echo "WARNING: imds-pod-block.service failed to start - pod-level IMDS access is NOT blocked on this node." >&2
  echo "Continuing with k3s agent install regardless; fix this separately." >&2
}

# ----------------------------------------------------------------------------
# 2. Fetch the cluster join token from Secrets Manager
# ----------------------------------------------------------------------------
K3S_TOKEN=$(aws secretsmanager get-secret-value \
  --region "${aws_region}" \
  --secret-id "${token_secret_arn}" \
  --query SecretString --output text)

# ----------------------------------------------------------------------------
# 3. Install k3s AGENT - kubelet + containerd only
# ----------------------------------------------------------------------------
curl -sfL https://get.k3s.io | \
  K3S_URL="https://${control_plane_private_ip}:6443" \
  K3S_TOKEN="$K3S_TOKEN" \
  sh -

dnf install -y amazon-cloudwatch-agent || echo "WARNING: amazon-cloudwatch-agent install failed, continuing without it" >&2
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s -c default || true
