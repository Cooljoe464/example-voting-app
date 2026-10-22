#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/kind-common.sh"

require_kind

if "$KIND_BIN" get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER"; then
  "$KIND_BIN" delete cluster --name "$KIND_CLUSTER"
else
  echo "kind cluster $KIND_CLUSTER does not exist"
fi
