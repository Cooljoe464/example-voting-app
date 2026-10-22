#!/usr/bin/env bash
set -euo pipefail

if [ -n "${ADMIN_CIDR:-}" ]; then
  case "$ADMIN_CIDR" in
    */*) printf '%s\n' "$ADMIN_CIDR" ;;
    *)   printf '%s/32\n' "$ADMIN_CIDR" ;;
  esac
  exit 0
fi

for url in https://checkip.amazonaws.com https://api.ipify.org; do
  if ip="$(curl -fsS --max-time 10 "$url" 2>/dev/null | tr -d '[:space:]')"; then
    if printf '%s' "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
      printf '%s/32\n' "$ip"
      exit 0
    fi
  fi
done

echo "ERROR: could not determine the administrator public IP. Set ADMIN_CIDR explicitly." >&2
exit 1
