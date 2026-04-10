FROM alpine:3.21

RUN apk add --no-cache skopeo bash jq webhook

COPY hooks/ /etc/webhook/
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

EXPOSE 9000
ENTRYPOINT ["webhook", "-hooks", "/etc/webhook/hooks.json", "-verbose", "-template"]
