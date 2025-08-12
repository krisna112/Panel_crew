#!/usr/bin/env bash
set -euo pipefail

# Common helpers
require_root() {
  if [[ $EUID -ne 0 ]]; then echo "[ERR] Run as root" >&2; exit 1; fi
}

log() { echo -e "\e[32m[OK]\e[0m $*"; }
warn() { echo -e "\e[33m[WARN]\e[0m $*"; }
err()  { echo -e "\e[31m[ERR]\e[0m $*"; exit 1; }

backup_file() {
  local f="$1"; [[ -f "$f" ]] || return 0
  local ts; ts=$(date +%Y%m%d-%H%M%S)
  cp -a "$f" "${f}.bak-${ts}"
  log "Backup: ${f}.bak-${ts}"
}

# Detect arch for Xray release asset
arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo amd64;;
    aarch64|arm64) echo arm64;;
    armv7l) echo armv7;;
    *) err "Unsupported arch: $(uname -m)";;
  esac
}

jq_check() { command -v jq >/dev/null || apt-get update && apt-get install -y jq; }

write_config() {
  local path="$1" json="$2"
  mkdir -p $(dirname "$path")
  backup_file "$path"
  echo "$json" > "$path"
  chmod 640 "$path"
  chown root:root "$path"
}

validate_config() {
  local path="$1"
  if ! xray -test -config "$path"; then
    err "xray -test failed for $path"
  fi
}

restart_xray() {
  systemctl daemon-reload || true
  systemctl enable xray >/dev/null 2>&1 || true
  systemctl restart xray
  systemctl --no-pager status xray -n 0 || true
}