#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/ministack-common.sh"

purge=0
if [ "${1:-}" = "--purge" ]; then
  purge=1
fi

while IFS= read -r id; do
  if [ -n "$id" ]; then
    "$DOCKER_BIN" rm -f "$id" >/dev/null 2>&1 || true
  fi
done < <("$DOCKER_BIN" ps -aq --filter "name=ministack-eks-")

if "$DOCKER_BIN" container inspect "$MINISTACK_CONTAINER" >/dev/null 2>&1; then
  "$DOCKER_BIN" stop "$MINISTACK_CONTAINER" >/dev/null
fi

if [ "$purge" -eq 1 ]; then
  if "$DOCKER_BIN" container inspect "$MINISTACK_CONTAINER" >/dev/null 2>&1; then
    "$DOCKER_BIN" rm -f "$MINISTACK_CONTAINER" >/dev/null
  fi
  if "$DOCKER_BIN" volume inspect "$MINISTACK_VOLUME" >/dev/null 2>&1; then
    "$DOCKER_BIN" volume rm "$MINISTACK_VOLUME" >/dev/null
  fi
  echo "MiniStack container and volume removed"
else
  echo "MiniStack stopped; volume $MINISTACK_VOLUME preserved"
  echo "EKS k3s containers are not restored after a MiniStack restart; destroy/recreate the ministack workspace."
fi
