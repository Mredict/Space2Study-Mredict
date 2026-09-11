#!/usr/bin/env bash
# Stops the 3 k3s EC2 nodes
# Usage: ./cluster-down.sh <project_name> <environment>
set -euo pipefail

PROJECT="${1:-space2study}"
ENV="${2:-dev}"

IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${PROJECT}-k3s-*-${ENV}" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" --output text)

if [ -z "$IDS" ]; then
  echo "No running nodes found matching ${PROJECT}-k3s-*-${ENV}."
  exit 0
fi

read -p "About to stop: $IDS - confirm? [y/N] " confirm
[ "$confirm" = "y" ] || { echo "Aborted."; exit 1; }

aws ec2 stop-instances --instance-ids $IDS
echo "Stopping. EBS volumes and Elastic IPs are untouched - next cluster-up.sh brings everything back as-is."
