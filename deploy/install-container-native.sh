#!/bin/bash
# Native install for Droidspaces Ubuntu (no Docker build — avoids kernel/Docker build restrictions).
set -euo pipefail

INSTALL_DIR="/opt/tinkerlab/codebuddy-telegram-bot-bridge"
REPO_ROOT="/opt/tinkerlab"
WORKSPACE="/workspace/tinkerlab"
SERVICE_NAME="codebuddy-telegram-bot-native.service"

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Run as root inside the Ubuntu container"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "→ Installing system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq python3.11 python3.11-venv ffmpeg rsync git curl

if ! command -v codebuddy >/dev/null 2>&1; then
    echo "→ Installing CodeBuddy CLI..."
    npm install -g @tencent-ai/codebuddy-code
fi

echo "→ Syncing bot source to $INSTALL_DIR"
mkdir -p "$REPO_ROOT" "$WORKSPACE/.telegram_bot/logs"
rsync -a --delete \
    --exclude '.git' --exclude 'venv' --exclude '.telegram_bot' \
    --exclude '__pycache__' \
    "$SRC_DIR/" "$INSTALL_DIR/"
ln -sfn "$INSTALL_DIR" "$REPO_ROOT/telegram_bot"

if [ ! -f "$INSTALL_DIR/deploy/runtime/bot.env" ]; then
    echo "❌ Missing deploy/runtime/bot.env"
    exit 1
fi

cp "$INSTALL_DIR/deploy/runtime/bot.env" "$INSTALL_DIR/.env"
mkdir -p "$WORKSPACE/.telegram_bot"
cp "$INSTALL_DIR/deploy/runtime/bot.env" "$WORKSPACE/.telegram_bot/.env"

echo "→ CodeBuddy config"
mkdir -p /root/.codebuddy
if [ -f /root/.codebuddy/settings.json ]; then
    echo "   keeping existing /root/.codebuddy (already configured)"
elif [ -d "$INSTALL_DIR/deploy/runtime/codebuddy" ] && [ -n "$(ls -A "$INSTALL_DIR/deploy/runtime/codebuddy" 2>/dev/null)" ]; then
    rsync -a "$INSTALL_DIR/deploy/runtime/codebuddy/" /root/.codebuddy/
else
    echo "   no bundled codebuddy config; ensure codebuddy auth is configured"
fi

echo "→ Python venv + dependencies"
python3.11 -m venv "$INSTALL_DIR/venv"
"$INSTALL_DIR/venv/bin/pip" install -q --upgrade pip
"$INSTALL_DIR/venv/bin/pip" install -q -r "$INSTALL_DIR/requirements.txt"

echo "→ systemd unit"
install -m 644 "$INSTALL_DIR/deploy/$SERVICE_NAME" "/etc/systemd/system/$SERVICE_NAME"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

sleep 4
systemctl --no-pager status "$SERVICE_NAME" || true
"$INSTALL_DIR/start.sh" --path "$WORKSPACE" --status || true
echo "✅ Native deploy complete. Logs: journalctl -u $SERVICE_NAME -f"
