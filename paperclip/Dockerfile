ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-nodejs:24
FROM ${BUILD_FROM}

# Доустанавливаем только гигабайтные утилиты, если они нужны
RUN apk add --no-cache git jq

# Установка Paperclip
RUN npm install -g paperclipai@latest

COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 3000

CMD [ "/run.sh" ]
