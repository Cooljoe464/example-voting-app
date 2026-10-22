#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_BIN="${TF_BIN:-terraform}"
cd "$ROOT"

"$TF_BIN" workspace select default >/dev/null

CIDR="$(bash "$ROOT/scripts/detect-cidr.sh")"
export TF_VAR_endpoint_public_access_cidrs="[\"$CIDR\"]"

echo "Using administrator CIDR: $CIDR"
echo "Using AWS profile: ${AWS_PROFILE:-<default>}"

"$TF_BIN" init -input=false -upgrade
"$TF_BIN" plan -out=terraform.tfplan
"$TF_BIN" apply -auto-approve terraform.tfplan
