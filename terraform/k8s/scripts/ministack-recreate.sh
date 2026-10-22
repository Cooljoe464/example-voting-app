#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/ministack-common.sh"

cd "$ROOT"

bash "$ROOT/scripts/ministack-up.sh"
select_ministack_workspace

cleanup_on_error() {
  local status=$?
  if [ "$status" -ne 0 ]; then
    echo "Lifecycle failed (exit $status); attempting cleanup destroy..." >&2
    "$TF_BIN" destroy -auto-approve -var-file=terraform.ministack.tfvars || true
  fi
  exit "$status"
}
trap cleanup_on_error EXIT

"$TF_BIN" init -input=false

echo
echo "========== APPLY #1 (MINISTACK) =========="
"$TF_BIN" apply -auto-approve -var-file=terraform.ministack.tfvars

echo
echo "========== VERIFY #1 (MINISTACK) =========="
bash "$ROOT/scripts/ministack-verify.sh"

echo
echo "========== DESTROY #1 (MINISTACK) =========="
"$TF_BIN" destroy -auto-approve -var-file=terraform.ministack.tfvars
bash "$ROOT/scripts/ministack-assert-destroyed.sh"

echo
echo "========== APPLY #2 (RECREATE FROM CODE) =========="
"$TF_BIN" apply -auto-approve -var-file=terraform.ministack.tfvars

echo
echo "========== VERIFY #2 (MINISTACK) =========="
bash "$ROOT/scripts/ministack-verify.sh"

if [ "${KEEP_CLUSTER:-0}" = "1" ]; then
  echo
  echo "KEEP_CLUSTER=1; leaving the MiniStack EKS cluster running"
  trap - EXIT
  echo "MiniStack lifecycle passed: apply -> verify -> destroy -> recreate -> verify."
  exit 0
fi

echo
echo "========== FINAL DESTROY (MINISTACK) =========="
"$TF_BIN" destroy -auto-approve -var-file=terraform.ministack.tfvars
bash "$ROOT/scripts/ministack-assert-destroyed.sh"

trap - EXIT

echo
echo "MiniStack lifecycle passed: apply -> verify -> destroy -> recreate -> verify -> destroy."
