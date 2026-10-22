#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"

KIND_BIN="${KIND_BIN:-kind}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
DOCKER_BIN="${DOCKER_BIN:-docker}"

KIND_CLUSTER="${KIND_CLUSTER:-voting-app}"
KIND_CONTEXT="kind-${KIND_CLUSTER}"

VOTE_IMAGE="${VOTE_IMAGE:-voting-app/vote:kind}"
RESULT_IMAGE="${RESULT_IMAGE:-voting-app/result:kind}"
WORKER_IMAGE="${WORKER_IMAGE:-voting-app/worker:kind}"

export KIND_BIN KUBECTL_BIN DOCKER_BIN

require_kind() {
  if ! command -v "$KIND_BIN" >/dev/null 2>&1; then
    echo "ERROR: kind is not installed or KIND_BIN is not executable." >&2
    echo "Install it with: winget install --id Kubernetes.kind --exact" >&2
    exit 1
  fi
}

kube() {
  "$KUBECTL_BIN" --context "$KIND_CONTEXT" "$@"
}
