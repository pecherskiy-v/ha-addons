#!/usr/bin/with-contenv bashio

# Прямое чтение параметров из файла конфигурации HA
OPTIONS_FILE="/data/options.json"

if [ -f "$OPTIONS_FILE" ]; then
    DB_URL=$(jq -r '.database_url // empty' "$OPTIONS_FILE")
    FAST_OLLAMA=$(jq -r '.fast_ollama_url // empty' "$OPTIONS_FILE")
    SMART_OLLAMA=$(jq -r '.smart_ollama_url // empty' "$OPTIONS_FILE")
    IMAGE_URL=$(jq -r '.image_gen_url // empty' "$OPTIONS_FILE")
    RUN_ONBOARDING=$(jq -r '.run_onboarding // false' "$OPTIONS_FILE")
fi

# Персистентное хранилище Paperclip
export HOME="/data"
export PAPERCLIP_HOME="/data/paperclip"
mkdir -p /data/paperclip

# Экспорт переменной DATABASE_URL (если она задана)
if [ -n "$DB_URL" ] && [ "$DB_URL" != "null" ]; then
    export DATABASE_URL="${DB_URL}"
    bashio::log.info "Database URL explicitly set: ${DATABASE_URL}"
else
    bashio::log.warning "DATABASE_URL is NOT set in config. Paperclip will attempt to use embedded Postgres."
fi

# Настройки LLM
export OLLAMA_BASE_URL="${FAST_OLLAMA}"
export SMART_OLLAMA_BASE_URL="${SMART_OLLAMA}"
export IMAGE_GEN_URL="${IMAGE_URL}"

export PORT=3000
export HOST="0.0.0.0"

bashio::log.info "Starting Paperclip AI Service..."
bashio::log.info "Fast Ollama: ${OLLAMA_BASE_URL}"
bashio::log.info "Smart Ollama: ${SMART_OLLAMA_BASE_URL}"

if [ "${RUN_ONBOARDING}" = "true" ]; then
    bashio::log.info "Running onboarding step (--yes)..."
    paperclipai onboard --yes || bashio::log.warning "Onboarding finished or skipped."
fi

export CI=true
export PAPERCLIP_NON_INTERACTIVE=true

exec paperclipai run
