#!/usr/bin/with-contenv bashio

# Чтение настроек из интерфейса Home Assistant
FAST_OLLAMA=$(bashio::config 'fast_ollama_url')
SMART_OLLAMA=$(bashio::config 'smart_ollama_url')
IMAGE_URL=$(bashio::config 'image_gen_url')

export OLLAMA_BASE_URL="${FAST_OLLAMA}"
export SMART_OLLAMA_BASE_URL="${SMART_OLLAMA}"
export IMAGE_GEN_URL="${IMAGE_URL}"
export PORT=3000

bashio::log.info "Starting Paperclip AI Service..."
bashio::log.info "Fast Ollama (Win 4060): ${OLLAMA_BASE_URL}"
bashio::log.info "Smart Ollama (Mac M5 Pro): ${SMART_OLLAMA_BASE_URL}"
bashio::log.info "Image Gen (Mac M5 Pro): ${IMAGE_GEN_URL}"

# Запуск службы Paperclip
if command -v paperclip &> /dev/null; then
    exec paperclip start --port 3000
else
    exec npx paperclipai start --port 3000
fi
