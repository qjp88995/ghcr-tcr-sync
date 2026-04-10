#!/usr/bin/env bash
set -euo pipefail

_on_failure() {
  echo "[$(date)] Sync failed: ${SOURCE:-} → ${TARGET:-}"
  if [[ -x /scripts/on-failure.sh ]]; then
    SYNC_SOURCE="${SOURCE:-}" \
    SYNC_TARGET="${TARGET:-}" \
    SYNC_PACKAGE="${PACKAGE:-}" \
    SYNC_TAG="${TAG:-}" \
    SYNC_OWNER="${OWNER:-}" \
    /scripts/on-failure.sh
  fi
}
trap '_on_failure' ERR

ACTION=$(echo "$HOOK_PAYLOAD" | jq -r '.action // ""')
if [[ "$ACTION" != "published" && "$ACTION" != "updated" ]]; then
  echo "[$(date)] Action is '$ACTION', skipping."
  exit 0
fi

OWNER=$(echo "$HOOK_PAYLOAD"   | jq -r '.registry_package.owner.login' | tr '[:upper:]' '[:lower:]')
PACKAGE=$(echo "$HOOK_PAYLOAD" | jq -r '.registry_package.name')
TAG=$(echo "$HOOK_PAYLOAD"     | jq -r '.registry_package.package_version.container_metadata.tag.name // ""')
if [[ -z "$TAG" || "$TAG" == "null" ]]; then
  echo "[$(date)] No tag found in payload, skipping."
  exit 0
fi

NAMESPACE="${TCR_NAMESPACE:-$OWNER}"

SOURCE="docker://ghcr.io/${OWNER}/${PACKAGE}:${TAG}"
TARGET="docker://${TCR_REGISTRY}/${NAMESPACE}/${PACKAGE}:${TAG}"

echo "[$(date)] Syncing: $SOURCE → $TARGET"

skopeo copy \
  --src-creds "${GHCR_USER}:${GHCR_TOKEN}" \
  --dest-creds "${TCR_USER}:${TCR_PASSWORD}" \
  "$SOURCE" "$TARGET"

echo "[$(date)] Done: $TARGET"
