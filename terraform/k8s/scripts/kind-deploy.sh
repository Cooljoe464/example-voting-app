#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/kind-common.sh"

kube apply -f "$REPO/k8s-specifications"

kube set image deployment/vote vote="$VOTE_IMAGE"
kube set image deployment/result result="$RESULT_IMAGE"
kube set image deployment/worker worker="$WORKER_IMAGE"

# The upstream manifests have no explicit pull policy, so Kubernetes defaulted
# it to Always for their untagged stock images. Force kind to use loaded images.
for deployment in vote result worker; do
  kube patch "deployment/$deployment" --type=json \
    -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'
done

# The hardened images listen on 8080. The upstream manifests still target 80.
kube patch service vote --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":8080}]'
kube patch service result --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/targetPort","value":8080}]'

for deployment in db redis vote result worker; do
  kube rollout status "deployment/$deployment" --timeout=300s
done

kube get pods -o wide
