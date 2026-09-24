#!/usr/bin/env bash
set -e

# HOME задаём здесь, а не только в environment манифеста: в прошлом запуске
# переменная до процесса не дошла (в логе «HOME=»), и CLI сложил .env и бинарь
# движка в /root — то есть вне тома, с потерей при каждом пересоздании
# контейнера.
export HOME=/data

PKG="$(npm root -g)/@agentmemory/agentmemory"

# Пакет несёт два конфига: iii-config.yaml слушает 127.0.0.1 (локальная
# установка), iii-config.docker.yaml — 0.0.0.0 и пути состояния в /data.
# CLI запускает движок именно с первым, поэтому подменяем его вторым: иначе
# сервис недостижим снаружи контейнера.
if [ -f "$PKG/dist/iii-config.docker.yaml" ]; then
  cp -f "$PKG/dist/iii-config.docker.yaml" "$PKG/dist/iii-config.yaml"
fi

mkdir -p "$HOME/.agentmemory"

# .env создаётся из шаблона только при первом запуске, чтобы не затирать
# настройки (там, в частности, EMBEDDING_PROVIDER и ключи).
if [ ! -f "$HOME/.agentmemory/.env" ]; then
  agentmemory init || true
fi

echo "[agentmemory] стартуем, HOME=$HOME, состояние в /data"
exec agentmemory
