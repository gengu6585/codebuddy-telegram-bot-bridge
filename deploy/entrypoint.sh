#!/bin/bash
set -euo pipefail

BOT_DIR="/opt/codebuddy-bot/bridge"
VENV="/opt/codebuddy-bot/venv"
PROJECT_ROOT="${PROJECT_ROOT:-/workspace/tinkerlab}"

mkdir -p "${PROJECT_ROOT}/.telegram_bot/logs"
mkdir -p /root/.codebuddy

cd /workspace
exec "${BOT_DIR}/start.sh" --path "${PROJECT_ROOT}" --_daemon_supervisor
