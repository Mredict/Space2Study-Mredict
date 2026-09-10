#!/usr/bin/env bash
# Starts the 3 k3s EC2 nodes for a study session
# Usage: ./cluster-up.sh <project_name> <environment>
set -euo pipefail

PROJECT="${1:-space2study}"
ENV="${2:-dev}"

IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${PROJECT}-k3s-node-*-${ENV}" "Name=instance-state-name,Values=stopped" \
  --query "Reservations[].Instances[].InstanceId" --output text)

if [ -z "$IDS" ]; then
  echo "No stopped nodes found matching ${PROJECT}-k3s-node-*-${ENV} (already running, or check tags/region)."
  exit 0
fi

echo "Starting nodes: $IDS"
aws ec2 start-instances --instance-ids $IDS

echo "Waiting for instances to reach 'running'..."
aws ec2 wait instance-running --instance-ids $IDS

echo "Waiting for SSM agent to check in (can take 1-2 min after boot)..."
for id in $IDS; do
  until aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=${id}" \
    --query "InstanceInformationList[0].PingStatus" --output text 2>/dev/null | grep -q Online; do
    sleep 5
  done
done

echo "All nodes online. Give k3s ~60-90s to re-form the etcd quorum, then:"
echo "  ./scripts/get-kubeconfig.sh ${PROJECT} ${ENV}"
