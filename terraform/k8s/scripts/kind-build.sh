#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/kind-common.sh"

"$DOCKER_BIN" build -t "$VOTE_IMAGE" "$REPO/vote"
"$DOCKER_BIN" build -t "$RESULT_IMAGE" "$REPO/result"
"$DOCKER_BIN" build -t "$WORKER_IMAGE" "$REPO/worker"

echo "Built: $VOTE_IMAGE $RESULT_IMAGE $WORKER_IMAGE"
