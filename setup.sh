#!/usr/bin/env bash
set -euo pipefail

# ===== Panel_crew unified installer (local repo) =====
# Usage:
#   sudo bash setup.sh
#   sudo bash setup.sh --with-api --gen-reality
#   sudo bash setup.sh --gen-vmess your.domain.com [/ws]
#
# Catatan:
# - Script ini TIDAK download dari repo orang lain. Semua dari folder repo lokal kamu.
# - Folder lain (ssh, wireguard, sstp, dll.) akan dijalankan kalau ada file "install*.sh" di dalamnya.

# --- Basic guards ---
if [[ "${EUID}" -ne 0 ]]; then
  echo "You need to run this script as root"; exit 1
fi
if [[ "$(systemd-detect-virt)" == "openvz" ]]; then
  echo "OpenVZ is not supported"; exit 1
fi

# --- Flags ---
WITH_API=0
GEN_REALITY=0
GEN_VMESS=0
VMESS_DOMAIN=""
WSPATH="/ws"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-api) WITH_API=1; shift ;;
    --gen-reality) GEN_REALITY=1; shift ;;
    --gen-vmess) GEN_VMESS=1; VMESS_DOMAIN=${2:?"need domain"}; WSPATH=${3:-/ws}; shift 3 || true ;;
    *) echo "[WARN] Unknown flag: $1"; shift ;;
  esac
done

# --- Paths ---
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
XRAY_DIR="$REPO_DIR/xray"

# --- Dependencies ---
export DEBIAN_FRONTEND=noninteractive
apt-get update -y || true
apt-get install -y curl git unzip jq python3 python3-pip ca-certificates screen || true

# --- Helper logging ---
ok(){ echo -e "\e[32m[OK]\e[0m $*"; }
warn(){ echo -e "\e[33m[WARN]\e[0m $*"; }
err(){ echo -e "\e[31m[ERR]\e[0m $*"; exit 1; }

# --- Installers in each folder (generic) ---
# Jalankan installer lokal bila ada "install*.sh"
run_installers_in_dir() {
  local d="$1"
  [[ -d "$d" ]] || return 0
  shopt -s nullglob
  local found=0
  for f in "$d"/install*.sh; do
    found=1
    chmod +x "$f" || true
    ok "Running $f"
    screen -S "inst-$(basename "$d")" -dm bash -c "$f; echo Done $f"
  done
  if [[ $found -eq 0 ]]; then
    warn "No installer found in $d (looking for install*.sh)"
  fi
}

# --- Xray (new secure setup) ---
if [[ -d "$XRAY_DIR" ]]; then
  chmod +x "$XRAY_DIR"/*.sh || true
  ok "Installing/Updating Xray-core"
  bash "$XRAY_DIR/install_xray.sh"

  if [[ $WITH_API -eq 1 ]]; then
    ok "Setting up Xray API (FastAPI) on :8787"
    pip3 install -r "$XRAY_DIR/api/requirements.txt"
    install -m 644 "$XRAY_DIR/api/api-xray.service" /etc/systemd/system/api-xray.service
    systemctl daemon-reload
    systemctl enable --now api-xray
  fi

  if [[ $GEN_REALITY -eq 1 ]]; then
    ok "Generating VLESS REALITY config (port 443, SNI www.cloudflare.com)"
    bash "$XRAY_DIR/gen_vless_reality.sh" 443 www.cloudflare.com
  fi

  if [[ $GEN_VMESS -eq 1 ]]; then
    ok "Generating VMess WS config for $VMESS_DOMAIN (TLS via reverse proxy)"
    bash "$XRAY_DIR/gen_vmess_ws_tls.sh" "$VMESS_DOMAIN" 443 "$(/usr/local/bin/xray uuid)" "$WSPATH"
  fi
else
  warn "Folder xray/ tidak ditemukan. Lewati instalasi Xray."
fi

# --- Install other stacks from your repo (if present) ---
for dir in ssh sstp ssr shadowsocks wireguard ipsec backup websocket ohp stunnel5 trojango; do
  run_installers_in_dir "$REPO_DIR/$dir"
done

# --- Post info ---
systemctl daemon-reload || true
ok "Installation has been completed!"
echo "Xray service status:"
systemctl status xray --no-pager || true
[[ $WITH_API -eq 1 ]] && echo "API status:" && systemctl status api-xray --no-pager || true

exit 0
