#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/opt/lojagamer
DEPLOY_USER="${SUDO_USER:-ec2-user}"

if [[ $EUID -ne 0 ]]; then
  echo "Rode com sudo." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  if command -v dnf >/dev/null 2>&1; then
    dnf install -y docker
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y docker.io
  fi
fi

systemctl enable --now docker
usermod -aG docker "$DEPLOY_USER"

mkdir -p "$APP_DIR/releases"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$APP_DIR"

if [[ ! -f "$APP_DIR/.env" ]]; then
  if [[ -f "$(dirname "$0")/.env.example" ]]; then
    cp "$(dirname "$0")/.env.example" "$APP_DIR/.env"
  fi
  chown "$DEPLOY_USER:$DEPLOY_USER" "$APP_DIR/.env"
  chmod 600 "$APP_DIR/.env"
fi
