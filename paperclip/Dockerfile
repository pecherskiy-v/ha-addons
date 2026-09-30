ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Установка Node.js 24 через Alpine Edge репозитории
RUN apk add --no-cache \
    git \
    jq \
    curl \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
    nodejs \
    npm

# Установка Paperclip
RUN npm install -g paperclipai@latest

COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 3000

CMD [ "/run.sh" ]
