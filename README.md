# ghcr-tcr-sync

[中文](README.zh.md)

Syncs container images from GitHub Container Registry (ghcr.io) to any Docker Registry v2 compatible registry via webhook.

## How It Works

1. GitHub fires a `registry_package` webhook event when an image is pushed to ghcr.io
2. The webhook server on your relay server receives the event and verifies the HMAC-SHA256 signature
3. `skopeo` copies the image directly from ghcr.io to the target registry without pulling it locally

## Prerequisites

- Docker with Traefik reverse proxy configured
- A domain pointing to your server

## Setup

**1. Clone and configure**

```bash
git clone <repo-url>
cd ghcr-tcr-sync
cp .env.example .env
# Edit .env with your credentials
```

**2. Start**

Use the pre-built image from GitHub Container Registry:

```bash
docker compose up -d
```

Or build locally:

```bash
docker compose up -d --build
```

**3. Configure GitHub webhook**

For each repository you want to sync, go to:
**Settings → Webhooks → Add webhook**

| Field | Value |
|-------|-------|
| Payload URL | `https://your-domain.com/hooks/sync-image` |
| Content type | `application/json` |
| Secret | Same as `WEBHOOK_SECRET` in `.env` |
| Events | Registry packages |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `WEBHOOK_DOMAIN` | Domain for the webhook server (e.g. `sync.example.com`) |
| `WEBHOOK_SECRET` | Shared secret for HMAC verification |
| `GHCR_USER` | GitHub username |
| `GHCR_TOKEN` | GitHub PAT with `read:packages` permission |
| `TCR_REGISTRY` | Target registry host (e.g. `ccr.ccs.tencentyun.com`, `registry.cn-hangzhou.aliyuncs.com`) |
| `TCR_NAMESPACE` | TCR namespace. Falls back to the source image owner if not set |
| `TCR_USER` | TCR username |
| `TCR_PASSWORD` | TCR password |

## Image Mapping

Source and target image names are derived automatically from the webhook payload:

```
ghcr.io/{owner}/{package}:{tag}  →  {TCR_REGISTRY}/{TCR_NAMESPACE}/{package}:{tag}
```

No additional configuration needed — any repository that sends a webhook to this server will have its images synced automatically.

## Target Registry Compatibility

Despite the `TCR_` prefix in variable names, the sync logic is registry-agnostic. Any registry that supports the Docker Registry v2 protocol works as a target:

| Registry | `TCR_REGISTRY` example |
|----------|------------------------|
| Tencent Cloud TCR | `ccr.ccs.tencentyun.com` |
| Alibaba Cloud ACR | `registry.cn-hangzhou.aliyuncs.com` |
| Self-hosted Harbor | `harbor.example.com` |
| Docker Hub | `registry-1.docker.io` |

## Triggering Sync from GitHub Actions

If your images are pushed via `GITHUB_TOKEN` in GitHub Actions, the `registry_package` webhook may not fire. In that case, trigger the sync manually from your workflow:

```yaml
- name: Trigger registry sync
  env:
    WEBHOOK_SECRET: ${{ secrets.SYNC_WEBHOOK_SECRET }}
  run: |
    PAYLOAD=$(jq -cn \
      --arg package "your-image" \
      --arg owner "${{ github.repository_owner }}" \
      --arg tag "latest" \
      '{action:"published",registry_package:{name:$package,owner:{login:$owner},package_version:{container_metadata:{tag:{name:$tag}}}}}')
    SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" | awk '{print "sha256="$2}')
    curl -sf -X POST ${{ secrets.SYNC_WEBHOOK_URL }}/hooks/sync-image \
      -H "Content-Type: application/json" \
      -H "X-Hub-Signature-256: $SIG" \
      -d "$PAYLOAD"
```
