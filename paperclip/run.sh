#!/usr/bin/with-contenv bashio

FAST_OLLAMA=$(bashio::config 'fast_ollama_url')
SMART_OLLAMA=$(bashio::config 'smart_ollama_url')
IMAGE_URL=$(bashio::config 'image_gen_url')
RUN_ONBOARDING=$(bashio::config 'run_onboarding')

# Переменные окружения подключения к LLM
export OLLAMA_BASE_URL="${FAST_OLLAMA}"
export SMART_OLLAMA_BASE_URL="${SMART_OLLAMA}"
export IMAGE_GEN_URL="${IMAGE_URL}"

export PORT=3000
export HOST="0.0.0.0"

bashio::log.info "Starting Paperclip AI Service..."
bashio::log.info "Fast Ollama: ${OLLAMA_BASE_URL}"
bashio::log.info "Smart Ollama: ${SMART_OLLAMA_BASE_URL}"
bashio::log.info "Image Gen: ${IMAGE_GEN_URL}"
bashio::log.info "Run Onboarding: ${RUN_ONBOARDING}"

# Автоматический первичный онбординг, если включено в конфиге
if [ "${RUN_ONBOARDING}" = "true" ]; then
    bashio::log.info "Running onboarding step (--yes)..."
    paperclipai onboard --yes || bashio::log.warning "Onboarding finished or already configured."
fi

# Неинтерактивные флаги для фоновой работы в контейнере
export CI=true
export PAPERCLIP_NON_INTERACTIVE=true

exec paperclipai run
