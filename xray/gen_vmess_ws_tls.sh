#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"
require_root; jq_check

DOMAIN=${1:?"Usage: $0 <domain> [port] [uuid] [wsPath]"}
PORT=${2:-443}
UUID=${3:-$(xray uuid)}
WSPATH=${4:-/ws}

# TLS assumed already provisioned by Nginx/Caddy/Traefik; we terminate TLS there
# Here we only set WS on 127.0.0.1:10000 and let reverse proxy handle TLS.

read -r -d '' JSON <<JSON
{
  "log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning"},
  "inbounds": [
    {
      "tag": "vmess-ws-in",
      "listen": "127.0.0.1",
      "port": 10000,
      "protocol": "vmess",
      "settings": {"clients": [{"id": "${UUID}", "alterId": 0}]},
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "${WSPATH}"}
      }
    }
  ],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "blocked"}
  ]
}
JSON

CONF=/etc/xray/20-vmess-ws.json
write_config "$CONF" "$JSON"
validate_config "$CONF"
restart_xray

log "Reverse proxy example (Nginx):"
cat <<NGINX
server {
  listen 443 ssl http2;
  server_name ${DOMAIN};
  ssl_protocols TLSv1.3;
  # ssl_certificate ...;
  # ssl_certificate_key ...;

  location ${WSPATH} {
    proxy_redirect off;
    proxy_pass http://127.0.0.1:10000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
  }
}
NGINX

log "Client JSON (VMess):"
cat <<CLI
{
  "v": "2",
  "ps": "vmess-ws-tls",
  "add": "${DOMAIN}",
  "port": "${PORT}",
  "id": "${UUID}",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "${DOMAIN}",
  "path": "${WSPATH}",
  "tls": "tls"
}
CLI