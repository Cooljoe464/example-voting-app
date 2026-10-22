#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"

TF_BIN="${TF_BIN:-terraform}"
AWS_BIN="${AWS_BIN:-aws}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"

MINISTACK_IMAGE="${MINISTACK_IMAGE:-ministackorg/ministack:1.5.31}"
MINISTACK_CONTAINER="${MINISTACK_CONTAINER:-ministack}"
MINISTACK_VOLUME="${MINISTACK_VOLUME:-ministack-data}"
MINISTACK_ENDPOINT="${MINISTACK_ENDPOINT:-http://localhost:4566}"
MINISTACK_REGION="${MINISTACK_REGION:-us-east-1}"
MINISTACK_K3S_IMAGE="${MINISTACK_K3S_IMAGE:-rancher/k3s:v1.34.12-k3s1}"
MINISTACK_WORKSPACE="${MINISTACK_WORKSPACE:-ministack}"
MINISTACK_KUBECONFIG="${MINISTACK_KUBECONFIG:-$ROOT/.kube/ministack-config}"
MINISTACK_ECR_PUSH_HOST="${MINISTACK_ECR_PUSH_HOST:-localhost:4566}"
MINISTACK_IMAGE_TAG="${MINISTACK_IMAGE_TAG:-ministack}"

if [ -z "${MINISTACK_DOCKER_SOCKET:-}" ]; then
  if [ "$(uname -s)" = "Linux" ] && [ -S /var/run/docker.sock ]; then
    MINISTACK_DOCKER_SOCKET="/var/run/docker.sock"
  else
    MINISTACK_DOCKER_SOCKET="/run/host-services/docker.proxy.sock"
  fi
fi

export TF_BIN AWS_BIN DOCKER_BIN KUBECTL_BIN
export MINISTACK_IMAGE MINISTACK_CONTAINER MINISTACK_VOLUME MINISTACK_ENDPOINT
export MINISTACK_REGION MINISTACK_K3S_IMAGE MINISTACK_WORKSPACE MINISTACK_KUBECONFIG
export MINISTACK_ECR_PUSH_HOST MINISTACK_IMAGE_TAG MINISTACK_DOCKER_SOCKET

export AWS_ENDPOINT_URL="$MINISTACK_ENDPOINT"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_REGION="$MINISTACK_REGION"
export AWS_DEFAULT_REGION="$MINISTACK_REGION"
export AWS_EC2_METADATA_DISABLED="true"
export AWS_PAGER=""
export KUBECONFIG="$MINISTACK_KUBECONFIG"

unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_SESSION_TOKEN

mkdir -p "$(dirname "$MINISTACK_KUBECONFIG")"

ministack_health() {
  curl -fsS --max-time 3 "$MINISTACK_ENDPOINT/_ministack/health" >/dev/null 2>&1
}

wait_for_ministack() {
  local attempts="${1:-120}"

  for _ in $(seq 1 "$attempts"); do
    if ministack_health; then
      return 0
    fi
    sleep 1
  done

  echo "ERROR: MiniStack did not become healthy at $MINISTACK_ENDPOINT" >&2
  "$DOCKER_BIN" logs --tail 60 "$MINISTACK_CONTAINER" >&2 || true
  return 1
}

select_ministack_workspace() {
  "$TF_BIN" workspace select -or-create "$MINISTACK_WORKSPACE" >/dev/null
}

aws_ministack() {
  "$AWS_BIN" --endpoint-url "$MINISTACK_ENDPOINT" "$@"
}

kube_ministack() {
  "$KUBECTL_BIN" --kubeconfig "$MINISTACK_KUBECONFIG" "$@"
}

docker_image_exists() {
  "$DOCKER_BIN" image inspect "$1" >/dev/null 2>&1
}

ensure_docker_image() {
  if ! docker_image_exists "$1"; then
    echo "Pulling $1"
    "$DOCKER_BIN" pull "$1"
  fi
}

ministack_k3s_container() {
  local cluster account region expected discovered

  cluster="$("$TF_BIN" output -raw cluster_name 2>/dev/null || true)"
  region="$("$TF_BIN" output -raw aws_region 2>/dev/null || true)"
  account="$(aws_ministack sts get-caller-identity --query Account --output text 2>/dev/null || true)"
  account="${account:-000000000000}"
  region="${region:-$MINISTACK_REGION}"

  if [ -n "$cluster" ]; then
    expected="ministack-eks-${account}-${region}-${cluster}"
    if "$DOCKER_BIN" container inspect "$expected" >/dev/null 2>&1; then
      printf '%s\n' "$expected"
      return 0
    fi
  fi

  discovered="$("$DOCKER_BIN" ps --filter "name=ministack-eks-" --format '{{.Names}}' | head -n 1)"
  if [ -n "$discovered" ]; then
    printf '%s\n' "$discovered"
    return 0
  fi

  echo "ERROR: no MiniStack EKS k3s container found" >&2
  return 1
}

ministack_ecr_registry() {
  "$TF_BIN" output -raw ecr_registry
}
