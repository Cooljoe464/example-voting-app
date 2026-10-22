#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/ministack-common.sh"

cd "$ROOT"

bash "$ROOT/scripts/ministack-up.sh"
select_ministack_workspace

REGISTRY="$("$TF_BIN" output -raw ecr_registry)"
REGION="$("$TF_BIN" output -raw aws_region)"

VOTE_IMAGE="voting-app/vote:${MINISTACK_IMAGE_TAG}"
RESULT_IMAGE="voting-app/result:${MINISTACK_IMAGE_TAG}"
WORKER_IMAGE="voting-app/worker:${MINISTACK_IMAGE_TAG}"
REDIS_IMAGE="redis:8.10.2-alpine"
DB_IMAGE="postgres:15.19-alpine"

for image in "$VOTE_IMAGE" "$RESULT_IMAGE" "$WORKER_IMAGE" "$REDIS_IMAGE" "$DB_IMAGE"; do
  if ! docker_image_exists "$image"; then
    echo "ERROR: image $image is missing. Run ./scripts/ministack-build.sh first." >&2
    exit 1
  fi
done

echo "==> Logging in to MiniStack ECR at $MINISTACK_ECR_PUSH_HOST"
if ! aws_ministack ecr get-login-password --region "$REGION" \
  | "$DOCKER_BIN" login --username AWS --password-stdin "$MINISTACK_ECR_PUSH_HOST" >/dev/null; then
  echo "WARN: Docker login failed; attempting anonymous push to MiniStack ECR." >&2
fi

push_image() {
  local source="$1"
  local repository="$2"
  local tag="$3"
  local target="$MINISTACK_ECR_PUSH_HOST/$repository:$tag"

  echo "Pushing $source -> $target"
  "$DOCKER_BIN" tag "$source" "$target"
  "$DOCKER_BIN" push "$target"
}

push_image "$VOTE_IMAGE" "voting-app/vote" "$MINISTACK_IMAGE_TAG"
push_image "$RESULT_IMAGE" "voting-app/result" "$MINISTACK_IMAGE_TAG"
push_image "$WORKER_IMAGE" "voting-app/worker" "$MINISTACK_IMAGE_TAG"
push_image "$REDIS_IMAGE" "voting-app/redis" "8.10.2-alpine"
push_image "$DB_IMAGE" "voting-app/db" "15.19-alpine"

echo "==> Verifying MiniStack ECR images"
for repository in vote result worker; do
  aws_ministack ecr describe-images \
    --repository-name "voting-app/$repository" \
    --image-ids "imageTag=$MINISTACK_IMAGE_TAG" \
    --region "$REGION" \
    --query 'imageDetails[0].imageTags' \
    --output text
done
aws_ministack ecr describe-images \
  --repository-name voting-app/redis \
  --image-ids imageTag=8.10.2-alpine \
  --region "$REGION" \
  --query 'imageDetails[0].imageTags' \
  --output text
aws_ministack ecr describe-images \
  --repository-name voting-app/db \
  --image-ids imageTag=15.19-alpine \
  --region "$REGION" \
  --query 'imageDetails[0].imageTags' \
  --output text

echo "MiniStack ECR push complete. Helm registry: $REGISTRY"
