#!/bin/bash
# Install CodeBuddy Telegram Bot Bridge into a Droidspaces Ubuntu container.
# Usage (inside container as root):
#   ./deploy/install-container.sh
set -euo pipefail

INSTALL_DIR="/opt/codebuddy-bot-src"
SERVICE_NAME="codebuddy-telegram-bot.service"

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Run as root inside the Ubuntu container"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "→ Stopping Mac/local duplicate if reachable..."
# Best-effort: same token cannot run twice

echo "→ Syncing source to $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
rsync -a --delete \
    --exclude '.git' --exclude 'venv' --exclude '.telegram_bot' \
    --exclude '__pycache__' \
    "$SRC_DIR/" "$INSTALL_DIR/"

if [ ! -f "$INSTALL_DIR/deploy/runtime/bot.env" ]; then
    echo "❌ Missing deploy/runtime/bot.env — run deploy/build-secrets-bundle.sh on your Mac first"
    exit 1
fi

echo "→ Building Docker image..."
cd "$INSTALL_DIR"
docker compose build --pull

echo "→ Installing systemd unit..."
install -m 644 "$INSTALL_DIR/deploy/$SERVICE_NAME" "/etc/systemd/system/$SERVICE_NAME"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

sleep 3
systemctl --no-pager status "$SERVICE_NAME" || true
docker ps --filter name=codebuddy-telegram-bot
echo "✅ Deployed. Logs: journalctl -u $SERVICE_NAME -f"
