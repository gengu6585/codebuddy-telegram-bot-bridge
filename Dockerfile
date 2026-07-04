# CodeBuddy Telegram Bot Bridge — aarch64/amd64
FROM python:3.11-slim-bookworm

ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates git ffmpeg \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g @tencent-ai/codebuddy-code \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/codebuddy-bot

# Bridge source (module name must be telegram_bot at runtime)
COPY requirements.txt ./bridge/requirements.txt
RUN python3 -m venv /opt/codebuddy-bot/venv \
    && /opt/codebuddy-bot/venv/bin/pip install --no-cache-dir -r bridge/requirements.txt

COPY . ./bridge/
RUN ln -sfn /opt/codebuddy-bot/bridge /opt/codebuddy-bot/telegram_bot

# CodeBuddy config + bot secrets (populated by deploy/build-secrets-bundle.sh)
COPY deploy/runtime/codebuddy/ /root/.codebuddy/
COPY deploy/runtime/bot.env /opt/codebuddy-bot/bridge/.env

RUN mkdir -p /workspace/tinkerlab

COPY deploy/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV HOME=/root \
    PROJECT_ROOT=/workspace/tinkerlab \
    PATH="/opt/codebuddy-bot/venv/bin:/usr/local/bin:${PATH}" \
    NODE_TLS_REJECT_UNAUTHORIZED=0

WORKDIR /workspace/tinkerlab
EXPOSE 8080

HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD /opt/codebuddy-bot/bridge/start.sh --path /workspace/tinkerlab --status || exit 1

ENTRYPOINT ["/entrypoint.sh"]
