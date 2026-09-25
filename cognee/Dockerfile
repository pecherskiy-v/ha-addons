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
# Сеть машины HA не вытягивает файл с extension.ladybugdb.com (20 КБ из 847 КБ
# за три минуты), поэтому расширение лежит в репозитории и раскладывается по
# путям кеша движка.
COPY vendor/libjson.lbug_extension /opt/ext/libjson.lbug_extension
COPY install-ext.py /tmp/install-ext.py
RUN set -eu; \
    for D in /data-seed/.lbdb/extension/v0.19.0/linux_amd64/json \
             /data-seed/.lbdb/extension/0.19.0/linux_amd64/json; do \
      mkdir -p "$D"; \
      cp /opt/ext/libjson.lbug_extension "$D/libjson.lbug_extension"; \
      cp /opt/ext/libjson.lbug_extension "$D/libjson.kuzu_extension"; \
    done; \
    HOME=/data-seed python /tmp/install-ext.py > /opt/ext-install.log 2>&1 || true; \
    cat /opt/ext-install.log

COPY reset-vectors.py /opt/reset-vectors.py
COPY run.sh /run.sh
RUN chmod +x /run.sh

# У базового образа свой ENTRYPOINT (/app/entrypoint.sh). Без сброса супервизор
# запустил бы «entrypoint.sh /run.sh», и наш скрипт ушёл бы в аргументы.
ENTRYPOINT []
CMD ["/run.sh"]
