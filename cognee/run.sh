#!/usr/bin/env bash
# Превращает опции аддона в переменные окружения Cognee и передаёт управление
# штатному entrypoint образа.
set -e
# shellcheck disable=SC1091
source /usr/lib/bashio/bashio.sh

opt() { bashio::config "$1"; }

# --- хранилища: реляционка и вектора в существующем Postgres с pgvector ---
export DB_PROVIDER="postgres"
export DB_HOST="$(opt db_host)"
export DB_PORT="$(opt db_port)"
export DB_NAME="$(opt db_name)"
export DB_USERNAME="$(opt db_user)"
export DB_PASSWORD="$(opt db_password)"
export VECTOR_DB_PROVIDER="pgvector"
# граф — встроенный kuzu, файлы рядом с остальными данными
export GRAPH_DATABASE_PROVIDER="kuzu"
export DATA_ROOT_DIRECTORY="/data/cognee_data"
export SYSTEM_ROOT_DIRECTORY="/data/cognee_system"
mkdir -p "$DATA_ROOT_DIRECTORY" "$SYSTEM_ROOT_DIRECTORY"

# --- модели ---
export LLM_PROVIDER="$(opt llm_provider)"
export LLM_ENDPOINT="$(opt llm_endpoint)"
export LLM_MODEL="$(opt llm_model)"
export LLM_API_KEY="$(opt llm_api_key)"
export EMBEDDING_PROVIDER="$(opt embedding_provider)"
export EMBEDDING_ENDPOINT="$(opt embedding_endpoint)"
export EMBEDDING_MODEL="$(opt embedding_model)"
export EMBEDDING_DIMENSIONS="$(opt embedding_dimensions)"

# --- сеть и режим ---
export TRANSPORT_MODE="http"
export HTTP_PORT="8000"
export MCP_ALLOWED_HOSTS="$(opt allowed_hosts)"
if [ "$(opt allowed_hosts)" = "*" ]; then
  # доверенная локальная сеть: защита от DNS-rebinding мешает клиентам с других машин
  export MCP_DISABLE_DNS_REBINDING_PROTECTION="true"
fi
export REQUIRE_AUTHENTICATION="False"
export LITELLM_LOG="$(opt log_level)"
export TOKENIZERS_PARALLELISM="false"

bashio::log.info "Cognee: база ${DB_NAME}@${DB_HOST}:${DB_PORT}, вектора в pgvector"
bashio::log.info "Модели: ${LLM_MODEL} через ${LLM_ENDPOINT}, эмбеддинги ${EMBEDDING_MODEL}"

exec /app/entrypoint.sh
