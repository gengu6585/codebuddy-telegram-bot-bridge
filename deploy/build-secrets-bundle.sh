#!/bin/bash
# Build deploy/runtime/ from local CodeBuddy config + bot .env (never commit output).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRIDGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$SCRIPT_DIR/runtime"
CODEBUDDY_SRC="${CODEBUDDY_HOME:-$HOME/.codebuddy}"
ENV_SRC="${BOT_ENV_FILE:-$BRIDGE_DIR/.env}"

mkdir -p "$RUNTIME_DIR/codebuddy"

copy_if_exists() {
    local src="$1" dst="$2"
    [ -e "$src" ] || return 0
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
}

echo "→ settings.json"
copy_if_exists "$CODEBUDDY_SRC/settings.json" "$RUNTIME_DIR/codebuddy/settings.json"

echo "→ mcp.json"
copy_if_exists "$CODEBUDDY_SRC/mcp.json" "$RUNTIME_DIR/codebuddy/mcp.json"

echo "→ local_storage/"
if [ -d "$CODEBUDDY_SRC/local_storage" ]; then
    rm -rf "$RUNTIME_DIR/codebuddy/local_storage"
    cp -a "$CODEBUDDY_SRC/local_storage" "$RUNTIME_DIR/codebuddy/local_storage"
fi

echo "→ plugins metadata"
copy_if_exists "$CODEBUDDY_SRC/plugins/known_marketplaces.json" \
    "$RUNTIME_DIR/codebuddy/plugins/known_marketplaces.json"

echo "→ .policy-cache.json"
copy_if_exists "$CODEBUDDY_SRC/.policy-cache.json" "$RUNTIME_DIR/codebuddy/.policy-cache.json"

if [ ! -f "$ENV_SRC" ]; then
    echo "❌ Bot env not found: $ENV_SRC" >&2
    exit 1
fi
cp "$ENV_SRC" "$RUNTIME_DIR/bot.env"

# Container has direct network — drop Mac-only proxy unless overridden
if [ "${KEEP_PROXY:-0}" != "1" ]; then
    sed -i.bak -E '/^(PROXY_URL|ALL_PROXY_URL|no_proxy)=/d' "$RUNTIME_DIR/bot.env" 2>/dev/null \
        || sed -i '' -E '/^(PROXY_URL|ALL_PROXY_URL|no_proxy)=/d' "$RUNTIME_DIR/bot.env"
    rm -f "$RUNTIME_DIR/bot.env.bak"
fi

echo "✅ Runtime bundle ready at $RUNTIME_DIR"
