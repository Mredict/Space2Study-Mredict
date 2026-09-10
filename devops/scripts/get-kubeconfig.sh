#!/usr/bin/env bash
# Pulls /etc/rancher/k3s/k3s.yaml off the init node via SSM Session Manager
# (no SSH key, no open port 22) and rewrites the server URL from
# 127.0.0.1 to the node's public Elastic IP so kubectl works from your laptop.
#
# Usage: ./get-kubeconfig.sh <project_name> <environment>
set -euo pipefail

PROJECT="${1:-space2study}"
ENV="${2:-dev}"

INIT_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${PROJECT}-k3s-node-0-${ENV}" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

if [ -z "$INIT_ID" ] || [ "$INIT_ID" = "None" ]; then
  echo "No running node-0 instance found matching ${PROJECT}-k3s-node-0-${ENV}." >&2
  echo "Check the tag name/region, or that terraform apply actually finished." >&2
  exit 1
fi

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INIT_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

# SSM Agent takes a minute or two to register after a fresh boot - a
# freshly-terraform-applied node hasn't necessarily finished that yet, and
# `send-command` against an unregistered instance fails with
# InvalidInstanceId ("not in a valid state"), which reads like a permissions
# problem but usually just means "give it a minute."
echo "Waiting for SSM Agent on $INIT_ID to register (can take 1-2 min after boot)..."
SSM_WAIT_SECS=0
until [ "$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=${INIT_ID}" \
    --query "InstanceInformationList[0].PingStatus" --output text 2>/dev/null)" = "Online" ]; do
  if [ "$SSM_WAIT_SECS" -ge 300 ]; then
    echo "SSM Agent still not registered after 5 minutes." >&2
    echo "Check: IAM instance profile actually attached, security group allows" >&2
    echo "outbound 443, and the instance's system log (EC2 console) for boot errors." >&2
    exit 1
  fi
  sleep 10
  SSM_WAIT_SECS=$((SSM_WAIT_SECS + 10))
done
echo "SSM Agent online."

# k3s itself can still be mid-install even once SSM is reachable (the
# bootstrap script downloads and installs k3s after SSM is already up), so
# retry the actual file read a few times before giving up.
echo "Fetching /etc/rancher/k3s/k3s.yaml (retrying if k3s is still installing)..."
ATTEMPT=0
CONTENT=""
while [ "$ATTEMPT" -lt 12 ]; do
  CMD_ID=$(aws ssm send-command \
    --instance-ids "$INIT_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["cat /etc/rancher/k3s/k3s.yaml"]' \
    --query "Command.CommandId" --output text)

  sleep 3
  aws ssm wait command-executed --command-id "$CMD_ID" --instance-id "$INIT_ID" || true

  CONTENT=$(aws ssm get-command-invocation \
    --command-id "$CMD_ID" --instance-id "$INIT_ID" \
    --query "StandardOutputContent" --output text)

  if echo "$CONTENT" | grep -q "server:"; then
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  echo "  k3s.yaml not ready yet, retrying in 10s (attempt $ATTEMPT/12)..."
  sleep 10
  CONTENT=""
done

if [ -z "$CONTENT" ]; then
  echo "Never got a valid k3s.yaml after 2 minutes of retries." >&2
  echo "k3s install may have failed on the node - check /var/log/cloud-init-output.log" >&2
  echo "on the instance via SSM Session Manager: aws ssm start-session --target $INIT_ID" >&2
  exit 1
fi

echo "$CONTENT" | sed "s/127.0.0.1/${PUBLIC_IP}/" > "./kubeconfig-${ENV}.yaml"
chmod 600 "./kubeconfig-${ENV}.yaml"
echo "Wrote ./kubeconfig-${ENV}.yaml"
echo "  export KUBECONFIG=\$(pwd)/kubeconfig-${ENV}.yaml"
echo "  kubectl get nodes"
