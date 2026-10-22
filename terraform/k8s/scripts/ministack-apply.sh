#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/ministack-common.sh"

cd "$ROOT"

bash "$ROOT/scripts/ministack-up.sh"
select_ministack_workspace

"$TF_BIN" init -input=false
"$TF_BIN" plan \
  -input=false \
  -var-file=terraform.ministack.tfvars \
  -out=terraform.ministack.tfplan
"$TF_BIN" apply -auto-approve terraform.ministack.tfplan
