#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/ministack-common.sh"

cd "$ROOT"

select_ministack_workspace
bash "$ROOT/scripts/assert-destroyed.sh"

for repository in vote result worker redis db; do
  if aws_ministack ecr describe-repositories \
    --repository-names "voting-app/$repository" \
    --region "$MINISTACK_REGION" >/dev/null 2>&1; then
    echo "ERROR: ECR repository voting-app/$repository still exists" >&2
    exit 1
  fi
done

leftovers="$("$DOCKER_BIN" ps -aq --filter "name=ministack-eks-")"
if [ -n "$leftovers" ]; then
  echo "ERROR: leftover MiniStack EKS k3s containers: $leftovers" >&2
  exit 1
fi

echo "MiniStack destroy verified: cluster, ECR repositories, and k3s containers are gone."
