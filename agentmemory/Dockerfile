# Собирается супервизором на самой машине: готового образа у agentmemory нет,
# а официальный iiidev/iii — distroless и без кода пакета (последний воркер в
# его конфиге запускает `node dist/index.mjs`, то есть нужен Node и сам пакет).
ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.19
FROM ${BUILD_FROM}

# Node нужен и для CLI, и для воркера agentmemory.
# curl — CLI качает бинарь движка iii с GitHub-релизов при первом старте.
RUN apk add --no-cache nodejs npm curl libstdc++

ARG AGENTMEMORY_VERSION=0.9.27
RUN npm install -g "@agentmemory/agentmemory@${AGENTMEMORY_VERSION}"

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
