#!/usr/bin/env bash
set -euo pipefail

ACTION=$(echo "$HOOK_PAYLOAD" | jq -r '.action // ""')
if [[ "$ACTION" != "published" && "$ACTION" != "updated" ]]; then
  echo "[$(date)] Action is '$ACTION', skipping."
  exit 0
fi

OWNER=$(echo "$HOOK_PAYLOAD"   | jq -r '.registry_package.owner.login' | tr '[:upper:]' '[:lower:]')
PACKAGE=$(echo "$HOOK_PAYLOAD" | jq -r '.registry_package.name')
TAG=$(echo "$HOOK_PAYLOAD"     | jq -r '.registry_package.package_version.container_metadata.tag.name')

NAMESPACE="${TCR_NAMESPACE:-$OWNER}"

SOURCE="docker://ghcr.io/${OWNER}/${PACKAGE}:${TAG}"
TARGET="docker://${TCR_REGISTRY}/${NAMESPACE}/${PACKAGE}:${TAG}"

echo "[$(date)] Syncing: $SOURCE → $TARGET"

skopeo copy \
  --src-creds "${GHCR_USER}:${GHCR_TOKEN}" \
  --dest-creds "${TCR_USER}:${TCR_PASSWORD}" \
  "$SOURCE" "$TARGET"

echo "[$(date)] Done: $TARGET"
