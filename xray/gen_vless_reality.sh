#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"
require_root; jq_check

# Inputs (with defaults)
PORT=${1:-443}
SERVER_NAME=${2:-"www.cloudflare.com"}  # target for reality handshake
UUID=${3:-$(xray uuid)}
# Generate x25519 keypair for REALITY
KEYS=$(xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | awk '/Private key/{print $3}')
PUBLIC_KEY=$(echo  "$KEYS" | awk '/Public key/{print $3}')
SHORT_ID=$(openssl rand -hex 8)

ROUTING=$(cat "$(dirname "$0")/sample-routing.json")

read -r -d '' JSON <<JSON
{
  "log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning"},
  "inbounds": [
    {
      "tag": "vless-reality-in",
      "listen": "0.0.0.0",
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "${UUID}", "flow": "xtls-rprx-vision"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${SERVER_NAME}:443",
          "xver": 0,
          "serverNames": ["${SERVER_NAME}"],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": ["${SHORT_ID}"]
        }
      }
    }
  ],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "blocked"}
  ],
  "routing": ${ROUTING}
}
JSON

CONF=/etc/xray/10-vless-reality.json
write_config "$CONF" "$JSON"
validate_config "$CONF"
restart_xray

log "Done. Client info:"
cat <<INFO
===== VLESS REALITY (Vision) =====
Address : YOUR_SERVER_IP
Port    : ${PORT}
UUID    : ${UUID}
Public  : ${PUBLIC_KEY}
SNI     : ${SERVER_NAME}
ShortID : ${SHORT_ID}
Flow    : xtls-rprx-vision
ALPN    : h2,http/1.1
INFO