# Qdrant

Векторная база. Данные — в `/data/storage`, снапшоты — в `/data/snapshots`;
оба каталога внутри тома дополнения, то есть переживают обновления и попадают
в бэкапы Home Assistant.

## Порты

- **6333** — HTTP API и веб-интерфейс: `http://<адрес-HA>:6333/dashboard`
- **6334** — gRPC

## Перенос данных с прежней машины

На текущем сервере (192.168.1.74) работает Qdrant 1.18.1 с коллекциями
`outline_docs` (4371 вектор), `stripe_docs` (9056), `docs`, `scripts`,
`parts_inventory`. Вариантов два.

**Снапшоты** — точная копия:

```bash
# на старом сервере: создать снапшот коллекции
curl -X POST http://192.168.1.74:6333/collections/outline_docs/snapshots

# скачать и загрузить в новый
curl -o out.snapshot http://192.168.1.74:6333/collections/outline_docs/snapshots/<имя>
curl -X POST http://<адрес-HA>:6333/collections/outline_docs/snapshots/upload \
  -H 'Content-Type: multipart/form-data' -F 'snapshot=@out.snapshot'
```

**Переиндексация с нуля** — чище, если исходные документы под рукой: 13 тысяч
векторов пересчитываются быстро, а заодно все они окажутся посчитаны одной и
той же моделью эмбеддера.

## Без авторизации

API открыт без ключа — предполагается закрытая домашняя сеть. Если нужен
ключ, добавьте `QDRANT__SERVICE__API_KEY` в `environment` манифеста.
