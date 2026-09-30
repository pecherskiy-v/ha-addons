ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm
FROM ${BUILD_FROM}

# Установка Node.js, git и системных зависимостей
RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    npm \
    git \
    jq \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Установка Paperclip глобально через npm
RUN npm install -g paperclipai@latest || npm install -g paperclip@latest

COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 3000

CMD [ "/run.sh" ]
