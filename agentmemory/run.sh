#!/usr/bin/env sh
set -e

PKG="$(npm root -g)/@agentmemory/agentmemory"

# Пакет несёт два конфига: iii-config.yaml слушает 127.0.0.1 (локальная
# установка), iii-config.docker.yaml — 0.0.0.0 и пути состояния в /data.
# Нам нужен второй: внутри контейнера 127.0.0.1 недостижим снаружи, и проброс
# порта супервизором такой сервис не увидит.
if [ -f "$PKG/dist/iii-config.docker.yaml" ]; then
  cp -f "$PKG/dist/iii-config.docker.yaml" "$PKG/dist/iii-config.yaml"
fi

# /data монтирует супервизор; он же попадает в бэкапы Home Assistant.
mkdir -p /data/.agentmemory

# .env нужен пакету; создаём из шаблона только при первом запуске, чтобы не
# затирать настройки (в нём, в частности, EMBEDDING_PROVIDER и ключи).
if [ ! -f /data/.agentmemory/.env ]; then
  agentmemory init || true
fi

echo "[agentmemory] стартуем, HOME=$HOME, состояние в /data"
exec agentmemory
