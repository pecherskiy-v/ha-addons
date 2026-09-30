ARG BUILD_FROM=paperclipai/paperclip:latest
FROM ${BUILD_FROM}

# Установка утилит bashio для работы с конфигами Home Assistant
RUN apk add --no-cache jq

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD [ "/run.sh" ]
