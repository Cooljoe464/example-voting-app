#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
TF_BIN="${TF_BIN:-terraform}"
AWS_BIN="${AWS_BIN:-aws}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
cd "$ROOT"

"$TF_BIN" workspace select default >/dev/null

REGION="$("$TF_BIN" output -raw aws_region)"
CLUSTER="$("$TF_BIN" output -raw cluster_name)"

echo "==> Cluster: $CLUSTER ($REGION)"
"$AWS_BIN" eks wait cluster-active --name "$CLUSTER" --region "$REGION"

"$AWS_BIN" eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

echo "==> Waiting for nodes"
"$KUBECTL_BIN" wait --for=condition=Ready nodes --all --timeout=900s
"$KUBECTL_BIN" get nodes -o wide

echo "==> Waiting for EKS addons"
for addon in vpc-cni kube-proxy coredns eks-pod-identity-agent; do
  status="$("$AWS_BIN" eks describe-addon \
    --cluster-name "$CLUSTER" \
    --addon-name "$addon" \
    --region "$REGION" \
    --query 'addon.status' \
    --output text)"
  echo "    $addon: $status"
  if [ "$status" != "ACTIVE" ]; then
    echo "ERROR: addon $addon is not ACTIVE" >&2
    exit 1
  fi
done

"$KUBECTL_BIN" get pods -n kube-system -o wide

echo "==> Deploying the voting application"
"$KUBECTL_BIN" apply -f "$REPO/k8s-specifications"

for deployment in db redis vote result worker; do
  "$KUBECTL_BIN" rollout status "deployment/$deployment" --timeout=300s
done

"$KUBECTL_BIN" get pods -o wide

smoke_test() {
  local pod="$1"
  local url="$2"

  "$KUBECTL_BIN" delete pod "$pod" --ignore-not-found >/dev/null 2>&1 || true
  "$KUBECTL_BIN" run "$pod" \
    --image=curlimages/curl:latest \
    --restart=Never \
    --command -- curl -fsS --max-time 15 "$url" >/dev/null

  local phase=""
  for _ in $(seq 1 60); do
    phase="$("$KUBECTL_BIN" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    case "$phase" in
      Succeeded) break ;;
      Failed)
        "$KUBECTL_BIN" logs "$pod" || true
        echo "ERROR: smoke test $pod failed" >&2
        exit 1
        ;;
    esac
    sleep 2
  done

  if [ "$phase" != "Succeeded" ]; then
    "$KUBECTL_BIN" describe pod "$pod" || true
    "$KUBECTL_BIN" logs "$pod" || true
    echo "ERROR: smoke test $pod did not complete (phase: ${phase:-unknown})" >&2
    exit 1
  fi

  echo "    $pod: HTTP OK ($url)"
}

echo "==> HTTP smoke tests"
smoke_test smoke-vote http://vote:8080/
smoke_test smoke-result http://result:8081/

echo "==> Removing application manifests"
"$KUBECTL_BIN" delete -f "$REPO/k8s-specifications" --ignore-not-found
"$KUBECTL_BIN" delete pod smoke-vote smoke-result --ignore-not-found

echo "Verification passed."
