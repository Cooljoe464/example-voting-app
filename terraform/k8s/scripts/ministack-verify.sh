#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/ministack-common.sh"

cd "$ROOT"

bash "$ROOT/scripts/ministack-up.sh"
select_ministack_workspace

CLUSTER="$("$TF_BIN" output -raw cluster_name)"
REGION="$("$TF_BIN" output -raw aws_region)"
EXPECTED_VERSION="$("$TF_BIN" output -raw cluster_version)"

STATUS="$(aws_ministack eks describe-cluster \
  --name "$CLUSTER" \
  --region "$REGION" \
  --query 'cluster.status' \
  --output text)"

VERSION="$(aws_ministack eks describe-cluster \
  --name "$CLUSTER" \
  --region "$REGION" \
  --query 'cluster.version' \
  --output text)"

if [ "$STATUS" != "ACTIVE" ]; then
  echo "ERROR: EKS cluster $CLUSTER is '$STATUS', expected ACTIVE" >&2
  exit 1
fi

if [ "$VERSION" != "$EXPECTED_VERSION" ]; then
  echo "ERROR: EKS cluster version is '$VERSION', expected '$EXPECTED_VERSION'" >&2
  exit 1
fi

echo "==> Cluster: $CLUSTER ($VERSION, $STATUS)"
echo "==> k3s container: $(ministack_k3s_container)"

mkdir -p "$(dirname "$MINISTACK_KUBECONFIG")"
aws_ministack eks update-kubeconfig \
  --name "$CLUSTER" \
  --region "$REGION" \
  --kubeconfig "$MINISTACK_KUBECONFIG"

echo "==> Waiting for the k3s node"
kube_ministack wait --for=condition=Ready nodes --all --timeout=300s
kube_ministack get nodes -o wide

echo "==> Kubernetes API smoke test"
kube_ministack create configmap ministack-smoke \
  --from-literal=ok=true \
  --namespace default \
  --dry-run=client \
  --output yaml | kube_ministack apply -f -
kube_ministack delete configmap ministack-smoke --namespace default

echo "==> ECR repositories"
for repository in vote result worker redis db; do
  name="voting-app/$repository"
  aws_ministack ecr describe-repositories \
    --repository-names "$name" \
    --region "$REGION" \
    --query 'repositories[0].repositoryUri' \
    --output text
done

echo "MiniStack verification passed."
