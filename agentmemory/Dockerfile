# Базовый образ намеренно НЕ из семейства HA: они на Alpine (musl), а движок iii
# публикуется только под glibc (ассеты релиза — *-unknown-linux-gnu, musl-сборки
# нет). Скачанный бинарь на musl не запускается и падает с ENOENT — загрузчик
# glibc отсутствует, ядро возвращает «нет такого файла».
#
# node:bookworm-slim = Debian (glibc) + уже установленный Node нужной версии
# (пакету требуется >=20). s6-overlay здесь нет, поэтому в config.yaml init
# оставлен по умолчанию (true) — init от Docker собирает зомби-процессы.
ARG BUILD_FROM=node:22-bookworm-slim
FROM ${BUILD_FROM}

# curl — CLI качает им бинарь движка с GitHub-релизов; ca-certificates нужны
# для https, в slim-образе их нет.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ARG AGENTMEMORY_VERSION=0.9.27
RUN npm install -g "@agentmemory/agentmemory@${AGENTMEMORY_VERSION}"

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
