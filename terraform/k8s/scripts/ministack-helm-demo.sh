#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/ministack-common.sh"

HELM_BIN="${HELM_BIN:-helm}"
if ! command -v "$HELM_BIN" >/dev/null 2>&1; then
  for candidate in "${LOCALAPPDATA:-}/Microsoft/WinGet/Packages"/Helm.Helm_*/windows-amd64/helm.exe; do
    if [ -x "$candidate" ]; then
      HELM_BIN="$candidate"
      break
    fi
  done
fi
if ! command -v "$HELM_BIN" >/dev/null 2>&1; then
  echo "ERROR: Helm was not found. Install it or set HELM_BIN." >&2
  exit 1
fi

CHART="$REPO/helm/voting-app"
RELEASE="voting-app"
NAMESPACE="voting-app"
HELM_TIMEOUT="5m"

cd "$ROOT"

bash "$ROOT/scripts/ministack-up.sh"
select_ministack_workspace

CLUSTER="$("$TF_BIN" output -raw cluster_name)"
REGION="$("$TF_BIN" output -raw aws_region)"
REGISTRY="$("$TF_BIN" output -raw ecr_registry)"

echo "==> Checking ECR images for release $RELEASE"
for repository in vote result worker redis db; do
  aws_ministack ecr describe-repositories \
    --repository-names "voting-app/$repository" \
    --region "$REGION" \
    --query 'repositories[0].repositoryUri' \
    --output text >/dev/null
done

echo "==> Ensuring kubeconfig points at $CLUSTER"
aws_ministack eks update-kubeconfig \
  --name "$CLUSTER" \
  --region "$REGION" \
  --kubeconfig "$MINISTACK_KUBECONFIG"
kube_ministack wait --for=condition=Ready nodes --all --timeout=300s

HELM=(
  "$HELM_BIN"
  --kubeconfig "$MINISTACK_KUBECONFIG"
  --namespace "$NAMESPACE"
)

http_check() {
  local deployment="$1"
  kube_ministack exec -n "$NAMESPACE" "deploy/$deployment" -- \
    curl -fsS --max-time 5 http://localhost:8080/ >/dev/null
}

verify_release() {
  kube_ministack rollout status "deploy/vote" -n "$NAMESPACE" --timeout=180s
  kube_ministack rollout status "deploy/result" -n "$NAMESPACE" --timeout=180s
  kube_ministack rollout status "deploy/worker" -n "$NAMESPACE" --timeout=180s
  kube_ministack rollout status "deploy/redis" -n "$NAMESPACE" --timeout=180s
  kube_ministack rollout status "deploy/db" -n "$NAMESPACE" --timeout=180s

  http_check vote
  http_check result

  kube_ministack get pods -n "$NAMESPACE" -o wide
  echo "==> HTTP checks passed (vote and result)"
}

echo
echo "========== HELM INSTALL =========="
"${HELM[@]}" upgrade --install "$RELEASE" "$CHART" \
  --create-namespace \
  --set "global.imageRegistry=$REGISTRY" \
  --wait \
  --timeout "$HELM_TIMEOUT"

verify_release
"${HELM[@]}" history "$RELEASE"

echo
echo "========== HELM BAD UPGRADE (EXPECTED TO FAIL) =========="
set +e
BAD_UPGRADE_OUTPUT="$("${HELM[@]}" upgrade "$RELEASE" "$CHART" \
  --set "global.imageRegistry=$REGISTRY" \
  --set vote.image.tag=does-not-exist \
  --set vote.replicaCount=2 \
  --wait \
  --timeout 90s 2>&1)"
BAD_UPGRADE_STATUS=$?
set -e

printf '%s\n' "$BAD_UPGRADE_OUTPUT"

if [ "$BAD_UPGRADE_STATUS" -eq 0 ]; then
  echo "ERROR: bad upgrade unexpectedly succeeded" >&2
  "${HELM[@]}" rollback "$RELEASE" 1 --wait --timeout "$HELM_TIMEOUT" || true
  exit 1
fi

echo "Bad upgrade failed as expected (exit $BAD_UPGRADE_STATUS)"
"${HELM[@]}" status "$RELEASE"
"${HELM[@]}" history "$RELEASE"

echo
echo "========== HELM ROLLBACK TO REVISION 1 =========="
"${HELM[@]}" rollback "$RELEASE" 1 --wait --timeout "$HELM_TIMEOUT"

verify_release
"${HELM[@]}" history "$RELEASE"

echo
echo "MiniStack Helm demo passed: install -> bad upgrade -> rollback."
