#!/usr/bin/env bash
# Поднимает сервер ha-mcp. База и настройки живут в /data и переживают
# обновление аддона; код обновляется из git при каждом старте.
set -e
# shellcheck disable=SC1091
source /usr/lib/bashio/bashio.sh

opt() { bashio::config "$1"; }

export HAMCP_DATA_DIR="/data"
export HAMCP_CONFIG_DIR="/data/config"
export HAMCP_API="local"
export HAMCP_OLLAMA="$(opt ollama_base)"
export HAMCP_EMBED_MODEL="$(opt embed_model)"
export HAMCP_CHAT_MODEL="$(opt chat_model)"
export HAMCP_WEB_HOST="0.0.0.0"
export HAMCP_WEB_PORT="8765"
mkdir -p "$HAMCP_CONFIG_DIR"

REF="$(opt git_ref)"
if git -C /app fetch --quiet origin "$REF" 2>/dev/null; then
  git -C /app reset --quiet --hard "origin/${REF}"
  bashio::log.info "код обновлён до $(git -C /app rev-parse --short HEAD) (ветка ${REF})"
else
  bashio::log.warning "обновить код не вышло — работаю на том, что в образе"
fi

bashio::log.info "база: ${HAMCP_DATA_DIR}/ha-mcp.db | Ollama: ${HAMCP_OLLAMA}"
exec python cli.py serve
