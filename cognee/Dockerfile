ARG BUILD_FROM=cognee/cognee-mcp:main
FROM ${BUILD_FROM}

# bashio нужен, чтобы читать опции аддона; jq для его работы
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq curl ca-certificates git \
 && rm -rf /var/lib/apt/lists/* \
 && git clone --depth 1 https://github.com/hassio-addons/bashio.git /tmp/bashio \
 && mv /tmp/bashio/lib /usr/lib/bashio \
 && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
 && rm -rf /tmp/bashio

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
