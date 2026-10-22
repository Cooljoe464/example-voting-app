#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/kind-common.sh"

require_kind

if "$KIND_BIN" get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER"; then
  echo "kind cluster $KIND_CLUSTER already exists"
else
  echo "Creating kind cluster $KIND_CLUSTER"
  "$KIND_BIN" create cluster --name "$KIND_CLUSTER" --wait 120s
fi

kube wait --for=condition=Ready nodes --all --timeout=180s
kube get nodes -o wide
