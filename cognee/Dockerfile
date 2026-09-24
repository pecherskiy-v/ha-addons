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

# Расширение json для графового движка тянется из сети при первом обращении и
# не укладывается в таймаут запроса. Ставим на сборке, в отдельный HOME,
# чтобы затем разложить кеш в /data.
RUN mkdir -p /data-seed \
 && HOME=/data-seed python -c "from cognee_db_workers._kuzu_helpers import install_json_extension_local; install_json_extension_local()" \
 && find /data-seed -maxdepth 3 | head -20

COPY run.sh /run.sh
RUN chmod +x /run.sh

# У базового образа свой ENTRYPOINT (/app/entrypoint.sh). Без сброса супервизор
# запустил бы «entrypoint.sh /run.sh», и наш скрипт ушёл бы в аргументы.
ENTRYPOINT []
CMD ["/run.sh"]
