#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/ministack-common.sh"

if ministack_health; then
  echo "MiniStack is already healthy at $MINISTACK_ENDPOINT"
  exit 0
fi

if "$DOCKER_BIN" container inspect "$MINISTACK_CONTAINER" >/dev/null 2>&1; then
  running="$("$DOCKER_BIN" inspect -f '{{.State.Running}}' "$MINISTACK_CONTAINER")"
  if [ "$running" = "true" ]; then
    echo "ERROR: MiniStack container is running but unhealthy at $MINISTACK_ENDPOINT" >&2
    "$DOCKER_BIN" logs --tail 60 "$MINISTACK_CONTAINER" >&2 || true
    exit 1
  fi

  echo "Starting existing MiniStack container"
  "$DOCKER_BIN" start "$MINISTACK_CONTAINER" >/dev/null
  wait_for_ministack
  echo "MiniStack is ready at $MINISTACK_ENDPOINT"
  exit 0
fi

conflicts="$("$DOCKER_BIN" ps --filter "publish=4566" --format '{{.Names}}')"
if [ -n "$conflicts" ]; then
  echo "ERROR: port 4566 is already published by: $conflicts" >&2
  echo "Stop that container before starting MiniStack." >&2
  exit 1
fi

ensure_docker_image "$MINISTACK_IMAGE"
if [ "${MINISTACK_PULL_K3S:-1}" = "1" ]; then
  ensure_docker_image "$MINISTACK_K3S_IMAGE"
fi

"$DOCKER_BIN" volume create "$MINISTACK_VOLUME" >/dev/null

echo "Starting MiniStack from $MINISTACK_IMAGE"
run_args=(
  run -d
  --name "$MINISTACK_CONTAINER"
  -p "4566:4566"
  -v "$MINISTACK_VOLUME:/tmp/ministack-state"
  -v "$MINISTACK_DOCKER_SOCKET:/var/run/docker.sock"
  -e PERSIST_STATE=1
  -e STATE_DIR=/tmp/ministack-state
  -e MINISTACK_AUTOCREATE_AWS_MANAGED=1
  -e "EKS_K3S_IMAGE=$MINISTACK_K3S_IMAGE"
  -e MINISTACK_HOST=localhost
  "$MINISTACK_IMAGE"
)

MSYS_NO_PATHCONV=1 "$DOCKER_BIN" "${run_args[@]}" >/dev/null

wait_for_ministack

echo "MiniStack is ready at $MINISTACK_ENDPOINT"
