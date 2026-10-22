#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/kind-common.sh"

require_kind

for image in "$VOTE_IMAGE" "$RESULT_IMAGE" "$WORKER_IMAGE"; do
  "$KIND_BIN" load docker-image --name "$KIND_CLUSTER" "$image"
done

echo "Loaded images into kind cluster $KIND_CLUSTER"
