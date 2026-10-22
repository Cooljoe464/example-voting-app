#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_BIN="${TF_BIN:-terraform}"
export TF_BIN
cd "$ROOT"

"$TF_BIN" workspace select default >/dev/null

CIDR="$(bash "$ROOT/scripts/detect-cidr.sh")"
export TF_VAR_endpoint_public_access_cidrs="[\"$CIDR\"]"

echo "Using administrator CIDR: $CIDR"
echo "Using AWS profile: ${AWS_PROFILE:-<default>}"

cleanup_on_error() {
  local status=$?
  if [ "$status" -ne 0 ]; then
    echo "Lifecycle failed (exit $status); attempting cleanup destroy..." >&2
    "$TF_BIN" destroy -auto-approve || true
  fi
  exit "$status"
}
trap cleanup_on_error EXIT

"$TF_BIN" init -input=false

echo
echo "========== APPLY #1 =========="
"$TF_BIN" apply -auto-approve

echo
echo "========== VERIFY #1 =========="
./scripts/verify.sh

echo
echo "========== DESTROY #1 =========="
"$TF_BIN" destroy -auto-approve
./scripts/assert-destroyed.sh

echo
echo "========== APPLY #2 (RECREATE FROM CODE) =========="
"$TF_BIN" apply -auto-approve

echo
echo "========== VERIFY #2 =========="
./scripts/verify.sh

echo
echo "========== FINAL DESTROY =========="
"$TF_BIN" destroy -auto-approve
./scripts/assert-destroyed.sh

trap - EXIT

echo
echo "Lifecycle test passed: apply -> verify -> destroy -> recreate -> verify -> destroy."
