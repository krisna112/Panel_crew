#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"
require_root

# Install deps
apt-get update
apt-get install -y curl tar jq ca-certificates socat

# Get latest Xray-core release tag (with fallback)
LATEST=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r .tag_name || true)
[[ -z "$LATEST" || "$LATEST" == null ]] && LATEST="v1.8.21"  # fallback pin

ARCH=$(arch)
URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST}/Xray-linux-${ARCH}.zip"
TMP=/tmp/xray
rm -rf "$TMP" && mkdir -p "$TMP"

log "Downloading Xray ${LATEST} for ${ARCH}"
curl -fsSL "$URL" -o "$TMP/xray.zip"
apt-get install -y unzip
unzip -qo "$TMP/xray.zip" -d "$TMP"
install -m 755 "$TMP/xray" /usr/local/bin/xray
install -m 755 "$TMP/xctl" /usr/local/bin/xctl || true

# Directories
mkdir -p /etc/xray /var/log/xray
chmod 750 /etc/xray

# Minimal service
cat >/etc/systemd/system/xray.service <<'UNIT'
[Unit]
Description=Xray Service
After=network-online.target
Wants=network-online.target

[Service]
User=root
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=/usr/local/bin/xray -confdir /etc/xray
Restart=on-failure
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
log "Xray ${LATEST} installed."