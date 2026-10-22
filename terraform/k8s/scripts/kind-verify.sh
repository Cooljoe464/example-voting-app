#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/kind-common.sh"

echo "==> HTTP smoke tests"
kube exec deployment/vote -- curl -fsS --max-time 15 http://localhost:8080/ >/dev/null
echo "    vote:   HTTP OK"

kube exec deployment/vote -- curl -fsS --max-time 15 \
  -X POST -d "vote=a" http://localhost:8080/ >/dev/null
echo "    vote:   POST accepted"

kube exec deployment/result -- curl -fsS --max-time 15 http://localhost:8080/ >/dev/null
echo "    result: HTTP OK"

echo "==> Pods"
kube get pods -o wide

echo "kind verification passed."
