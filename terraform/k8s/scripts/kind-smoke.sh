#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/kind-common.sh"

require_kind

cleanup() {
  local status=$?

  if [ "$status" -ne 0 ]; then
    echo "kind smoke test failed (exit $status)" >&2
    kube get pods -o wide || true
    kube get events --sort-by=.lastTimestamp | tail -30 || true
  fi

  if [ "${KEEP_CLUSTER:-0}" = "1" ]; then
    echo "KEEP_CLUSTER=1; leaving kind cluster $KIND_CLUSTER running"
  else
    bash "$ROOT/scripts/kind-down.sh" || true
  fi

  exit "$status"
}
trap cleanup EXIT

bash "$ROOT/scripts/kind-up.sh"
bash "$ROOT/scripts/kind-build.sh"
bash "$ROOT/scripts/kind-load.sh"
bash "$ROOT/scripts/kind-deploy.sh"
bash "$ROOT/scripts/kind-verify.sh"

echo
echo "kind smoke test passed: hardened images deployed and vote/result responded."
