#!/bin/bash
# Clone/update fork from GitHub and run native systemd install inside Droidspaces Ubuntu.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Run as root inside the Ubuntu container"
    exit 1
fi

REPO_URL="${REPO_URL:-https://github.com/gengu6585/codebuddy-telegram-bot-bridge.git}"
BRANCH="${BRANCH:-master}"
CLONE_DIR="${CLONE_DIR:-/tmp/codebuddy-telegram-bot-bridge-src}"

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
    echo "❌ Set TELEGRAM_BOT_TOKEN before running"
    exit 1
fi

echo "→ Fetch source from $REPO_URL ($BRANCH)"
rm -rf "$CLONE_DIR"
if [ -n "${GITHUB_PAT:-}" ]; then
    AUTH_URL="${REPO_URL/https:\/\/github.com/https://gengu6585:${GITHUB_PAT}@github.com}"
    git clone --depth 1 --branch "$BRANCH" "$AUTH_URL" "$CLONE_DIR"
else
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$CLONE_DIR"
fi

mkdir -p "$CLONE_DIR/deploy/runtime"
cat > "$CLONE_DIR/deploy/runtime/bot.env" <<EOF
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
LOG_LEVEL=INFO
CLAUDE_PROCESS_TIMEOUT=600
DRAFT_UPDATE_MIN_CHARS=30
DRAFT_UPDATE_INTERVAL=1.0
EOF

echo "→ Running native install"
bash "$CLONE_DIR/deploy/install-container-native.sh"
