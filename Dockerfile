FROM alpine:3.21

RUN apk add --no-cache skopeo bash jq webhook

EXPOSE 9000
ENTRYPOINT ["webhook", "-hooks", "/etc/webhook/hooks.json", "-verbose", "-template"]
