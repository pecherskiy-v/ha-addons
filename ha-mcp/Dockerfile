ARG BUILD_FROM=python:3.12-slim
FROM ${BUILD_FROM}

# Проекту зависимостей не нужно — только Python. git нужен, чтобы тянуть код,
# bashio — чтобы читать опции аддона.
RUN apt-get update \
 && apt-get install -y --no-install-recommends git jq curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && git clone --depth 1 https://github.com/hassio-addons/bashio.git /tmp/bashio \
 && mv /tmp/bashio/lib /usr/lib/bashio \
 && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
 && rm -rf /tmp/bashio

RUN git clone --depth 1 https://github.com/pecherskiy-v/ha-mcp.git /app

COPY run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /app
ENTRYPOINT []
CMD ["/run.sh"]
