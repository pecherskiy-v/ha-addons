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
# не укладывается в таймаут запроса. Ставим на сборке; итог пишем в файл,
# чтобы причину отказа было видно без журналов супервизора.
COPY install-ext.py /tmp/install-ext.py
RUN mkdir -p /data-seed && HOME=/data-seed python /tmp/install-ext.py > /opt/ext-install.log 2>&1; \
    cat /opt/ext-install.log

COPY run.sh /run.sh
RUN chmod +x /run.sh

# У базового образа свой ENTRYPOINT (/app/entrypoint.sh). Без сброса супервизор
# запустил бы «entrypoint.sh /run.sh», и наш скрипт ушёл бы в аргументы.
ENTRYPOINT []
CMD ["/run.sh"]
