# ghcr-tcr-sync

Webhook server that syncs container images from ghcr.io to Tencent Cloud TCR.

## Stack

- **webhook** (adnanh/webhook) — receives and verifies GitHub webhook events
- **skopeo** — copies images directly between registries without local storage
- **Docker Compose** — deployment, integrated with Traefik for HTTPS

## Project Structure

```
Dockerfile          # Alpine image with webhook + skopeo + jq
docker-compose.yml  # Service definition with Traefik labels
hooks/
  hooks.json        # Webhook route config (uses -template flag for env vars)
scripts/
  sync.sh           # Sync logic: parse payload → skopeo copy
.env.example        # Environment variable reference
```

## Key Behaviors

- `hooks.json` uses Go Template syntax (`{{ getenv \`VAR\` }}`) for env vars — requires `-template` flag in ENTRYPOINT
- Webhook tool prefixes all `pass-environment-to-command` vars with `HOOK_`, so the payload is available as `$HOOK_PAYLOAD` in scripts
- `TCR_NAMESPACE` is optional — falls back to the source image owner login
- Handles both `published` and `updated` actions from GitHub registry_package events
