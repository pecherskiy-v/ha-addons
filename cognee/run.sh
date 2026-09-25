#!/usr/bin/env bash
# Превращает опции аддона в переменные окружения Cognee и передаёт управление
# штатному entrypoint образа.
set -e
# shellcheck disable=SC1091
source /usr/lib/bashio/bashio.sh

opt() { bashio::config "$1"; }

# --- хранилища: реляционка и вектора в существующем Postgres с pgvector ---
export DB_PROVIDER="postgres"
export DB_HOST="$(opt db_host)"
export DB_PORT="$(opt db_port)"
export DB_NAME="$(opt db_name)"
export DB_USERNAME="$(opt db_user)"
DB_PASSWORD="$(opt db_password)"
# Пароль не дублируем: если поле пустое, берём его у аддона PostgreSQL через
# API супервизора. Источник правды один — конфигурация того аддона.
if [ -z "$DB_PASSWORD" ]; then
  SRC="$(opt db_password_from_addon)"
  if [ -n "$SRC" ] && [ -n "${SUPERVISOR_TOKEN:-}" ]; then
    DB_PASSWORD="$(curl -sS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
      "http://supervisor/addons/${SRC}/info" \
      | jq -r '.data.options.ha_user_password // empty')"
    if [ -n "$DB_PASSWORD" ]; then
      bashio::log.info "Пароль получен из аддона ${SRC}"
    else
      bashio::log.warning "Не удалось получить пароль из аддона ${SRC}"
    fi
  fi
fi
export DB_PASSWORD
export VECTOR_DB_PROVIDER="pgvector"
# При включённом контроле доступа адаптер pgvector требует собственные
# реквизиты и не наследует реляционные — передаём те же значения явно.
export VECTOR_DB_HOST="$DB_HOST"
export VECTOR_DB_PORT="$DB_PORT"
export VECTOR_DB_NAME="$DB_NAME"
export VECTOR_DB_USERNAME="$DB_USERNAME"
export VECTOR_DB_PASSWORD="$DB_PASSWORD"
# граф — встроенный kuzu, файлы рядом с остальными данными
export GRAPH_DATABASE_PROVIDER="kuzu"
# Кеши и конфиги пишем в /data — единственный каталог, переживающий обновление.
export HOME="/data"
export DATA_ROOT_DIRECTORY="/data/cognee_data"
export SYSTEM_ROOT_DIRECTORY="/data/cognee_system"
mkdir -p "$DATA_ROOT_DIRECTORY" "$SYSTEM_ROOT_DIRECTORY"

# --- модели ---
export LLM_PROVIDER="$(opt llm_provider)"
export LLM_ENDPOINT="$(opt llm_endpoint)"
export LLM_MODEL="$(opt llm_model)"
export LLM_API_KEY="$(opt llm_api_key)"
# Слабые локальные модели часто отдают объект там, где схема ждёт строку.
# instructor переспрашивает модель, показывая ей текст ошибки валидации;
# ему нужен OpenAI-совместимый адрес (с /v1), в отличие от litellm_native.
export STRUCTURED_OUTPUT_FRAMEWORK="$(opt structured_output)"
if [ "$(opt structured_output)" = "instructor" ]; then
  export LLM_ENDPOINT="${LLM_ENDPOINT%/}/v1"
  bashio::log.info "structured output: instructor, адрес ${LLM_ENDPOINT}"
fi
export EMBEDDING_PROVIDER="$(opt embedding_provider)"
export EMBEDDING_ENDPOINT="$(opt embedding_endpoint)"
export EMBEDDING_MODEL="$(opt embedding_model)"
export EMBEDDING_DIMENSIONS="$(opt embedding_dimensions)"

# --- сеть и режим ---
export TRANSPORT_MODE="http"
export HTTP_PORT="8000"
export MCP_ALLOWED_HOSTS="$(opt allowed_hosts)"
if [ "$(opt allowed_hosts)" = "*" ]; then
  # доверенная локальная сеть: защита от DNS-rebinding мешает клиентам с других машин
  export MCP_DISABLE_DNS_REBINDING_PROTECTION="true"
fi
# Мультитенантный режим Cognee заводит ОТДЕЛЬНУЮ базу на каждый датасет
# (CREATE DATABASE "<uuid>") — для этого нужен ha_user с правом CREATEDB.
# Для одного владельца это лишнее: держим всё в одной базе, которая уже
# попадает в бэкап аддона Postgres.
if bashio::config.true 'dataset_isolation'; then
  export ENABLE_BACKEND_ACCESS_CONTROL="True"
  bashio::log.info "Изоляция датасетов включена — БД должна позволять CREATE DATABASE"
else
  export ENABLE_BACKEND_ACCESS_CONTROL="False"
  bashio::log.info "Все датасеты в одной базе ${DB_NAME}"
fi
export REQUIRE_AUTHENTICATION="False"
export LITELLM_LOG="$(opt log_level)"
export TOKENIZERS_PARALLELISM="false"

# Графовый движок при первом обращении тянет расширение json из сети. Внутри
# запроса он не успевает (загрузка ~30с) и миграции падают — ставим заранее,
# один раз; кеш остаётся в /data.
if [ ! -f /data/.ladybug-json-installed ]; then
  if [ -f /opt/ext-install.log ]; then
    cp /opt/ext-install.log /data/ext-install.log 2>/dev/null || true
  fi
  if [ -d /data-seed ]; then
    cp -rn /data-seed/. "$HOME"/ 2>/dev/null || true
    bashio::log.info "Кеш расширений разложен из образа"
  fi
  if python -c "from cognee_db_workers._kuzu_helpers import install_json_extension_local; install_json_extension_local()"; then
    touch /data/.ladybug-json-installed
    bashio::log.info "Расширение json готово"
  else
    bashio::log.warning "Расширение json поставить не удалось — миграции графа будут падать"
  fi
fi

# Разовый сброс векторных таблиц: нужен при смене модели эмбеддингов,
# иначе Cognee пишет вектор новой длины в таблицу со старой размерностью.
if bashio::config.true 'reset_vector_store'; then
  bashio::log.warning "reset_vector_store включён — удаляю векторные таблицы Cognee"
  python /opt/reset-vectors.py || bashio::log.error "сброс не удался"
  bashio::log.warning "выключи reset_vector_store, иначе таблицы будут сноситься при каждом старте"
fi

bashio::log.info "Cognee: база ${DB_NAME}@${DB_HOST}:${DB_PORT}, вектора в pgvector"
bashio::log.info "Модели: ${LLM_MODEL} через ${LLM_ENDPOINT}, эмбеддинги ${EMBEDDING_MODEL}"

exec /app/entrypoint.sh
