#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v act >/dev/null 2>&1; then
  echo "ERROR: act is not installed. Install it with: winget install --id nektos.act -e" >&2
  exit 1
fi

act --list

echo
echo "========== PUSH EVENT (registry push disabled by ACT=true) =========="
act push -W .github/workflows/ci.yml

echo
echo "========== PULL REQUEST EVENT (registry push disabled) =========="
act pull_request -W .github/workflows/ci.yml
