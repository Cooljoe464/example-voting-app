#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TF_BIN="${TF_BIN:-terraform}"
AWS_BIN="${AWS_BIN:-aws}"
AWS_ARGS=()

if [ -n "${AWS_ENDPOINT_URL:-}" ]; then
  AWS_ARGS+=(--endpoint-url "$AWS_ENDPOINT_URL")
fi

REGION="${AWS_REGION:-$("$TF_BIN" output -raw aws_region 2>/dev/null || true)}"
REGION="${REGION:-us-east-1}"
CLUSTER="${CLUSTER_NAME:-$("$TF_BIN" output -raw cluster_name 2>/dev/null || true)}"
CLUSTER="${CLUSTER:-voting-app-eks}"

if "$AWS_BIN" "${AWS_ARGS[@]}" eks describe-cluster --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1; then
  echo "ERROR: EKS cluster $CLUSTER still exists" >&2
  exit 1
fi

VPC_ID="$("$AWS_BIN" "${AWS_ARGS[@]}" ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --region "$REGION" \
  --query 'Vpcs[0].VpcId' \
  --output text)"

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
  echo "ERROR: the default VPC is missing after destroy" >&2
  exit 1
fi

INSTANCES="$("$AWS_BIN" "${AWS_ARGS[@]}" ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=tag:eks:cluster-name,Values=$CLUSTER" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)"

if [ -n "$INSTANCES" ]; then
  echo "ERROR: leftover instances: $INSTANCES" >&2
  exit 1
fi

ASGS="$("$AWS_BIN" "${AWS_ARGS[@]}" autoscaling describe-auto-scaling-groups \
  --region "$REGION" \
  --query "AutoScalingGroups[?contains(AutoScalingGroupName, '$CLUSTER')].AutoScalingGroupName" \
  --output text)"

if [ -n "$ASGS" ]; then
  echo "ERROR: leftover Auto Scaling groups: $ASGS" >&2
  exit 1
fi

echo "Destroy verified: EKS cluster gone, default VPC $VPC_ID intact, no leftover nodes or ASGs."
