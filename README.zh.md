# ghcr-tcr-sync

[English](README.md)

通过 Webhook 将容器镜像从 GitHub Container Registry (ghcr.io) 同步到腾讯云 TCR。

## 工作原理

1. 镜像推送到 ghcr.io 后，GitHub 触发 `registry_package` Webhook 事件
2. 中转服务器上的 Webhook 服务接收事件并验证 HMAC-SHA256 签名
3. `skopeo` 直接在两个 Registry 之间复制镜像，无需本地拉取

## 前置条件

- 已配置 Traefik 反向代理的 Docker 环境
- 一个指向服务器的域名

## 部署

**1. 克隆并配置**

```bash
git clone <repo-url>
cd ghcr-tcr-sync
cp .env.example .env
# 编辑 .env 填入凭据
```

**2. 启动**

使用 GitHub Container Registry 上的预构建镜像：

```bash
docker compose up -d
```

或本地构建：

```bash
docker compose up -d --build
```

**3. 配置 GitHub Webhook**

对每个需要同步的仓库，前往：
**Settings → Webhooks → Add webhook**

| 字段 | 值 |
|------|----|
| Payload URL | `https://your-domain.com/hooks/sync-image` |
| Content type | `application/json` |
| Secret | 与 `.env` 中的 `WEBHOOK_SECRET` 相同 |
| Events | Registry packages |

## 环境变量

| 变量 | 说明 |
|------|------|
| `WEBHOOK_DOMAIN` | Webhook 服务的域名（如 `sync.example.com`） |
| `WEBHOOK_SECRET` | 用于 HMAC 验证的共享密钥 |
| `GHCR_USER` | GitHub 用户名 |
| `GHCR_TOKEN` | 具有 `read:packages` 权限的 GitHub PAT |
| `TCR_REGISTRY` | TCR Registry 地址（如 `ccr.ccs.tencentyun.com`） |
| `TCR_NAMESPACE` | TCR 命名空间，不设置时回退为源镜像的 owner |
| `TCR_USER` | TCR 用户名 |
| `TCR_PASSWORD` | TCR 密码 |

## 镜像映射

镜像名称自动从 Webhook payload 中解析：

```
ghcr.io/{owner}/{package}:{tag}  →  {TCR_REGISTRY}/{TCR_NAMESPACE}/{package}:{tag}
```

无需额外配置——任何向此服务发送 Webhook 的仓库都会自动同步镜像。

## 目标 Registry 兼容性

尽管变量名带有 `TCR_` 前缀，同步逻辑本身与 Registry 无关。任何支持 Docker Registry v2 协议的 Registry 均可作为目标：

| Registry | `TCR_REGISTRY` 示例 |
|----------|---------------------|
| 腾讯云 TCR | `ccr.ccs.tencentyun.com` |
| 阿里云 ACR | `registry.cn-hangzhou.aliyuncs.com` |
| 自建 Harbor | `harbor.example.com` |
| Docker Hub | `registry-1.docker.io` |

## 从 GitHub Actions 触发同步

若镜像通过 `GITHUB_TOKEN` 在 GitHub Actions 中推送，`registry_package` Webhook 可能不会触发。此时可在 workflow 中手动触发同步：

```yaml
- name: Trigger TCR sync
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
