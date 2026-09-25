"""Удалить векторные таблицы Cognee, когда меняется размерность эмбеддингов.

Cognee не пересоздаёт их сам: после смены модели он пытается класть вектор
другой длины и падает с «expected N dimensions». Свои таблицы он отличает
колонкой `vector`; наши таблицы агентов используют `embedding` и не трогаются.
"""
import os
import sys

import psycopg2

dsn = "postgresql://{u}:{p}@{h}:{port}/{db}".format(
    u=os.environ["DB_USERNAME"], p=os.environ["DB_PASSWORD"],
    h=os.environ["DB_HOST"], port=os.environ["DB_PORT"], db=os.environ["DB_NAME"],
)

with psycopg2.connect(dsn, connect_timeout=10) as conn, conn.cursor() as cur:
    cur.execute("""
        SELECT c.table_name
        FROM information_schema.columns c
        JOIN information_schema.tables t
          ON t.table_schema = c.table_schema AND t.table_name = c.table_name
        WHERE c.table_schema = 'public'
          AND c.column_name = 'vector'
          AND t.table_type = 'BASE TABLE'
    """)
    tables = [r[0] for r in cur.fetchall()]
    if not tables:
        print("векторных таблиц Cognee не найдено — нечего сбрасывать")
        sys.exit(0)
    for name in tables:
        cur.execute(f'DROP TABLE IF EXISTS "{name}" CASCADE')
        print("удалена таблица", name)
print(f"сброшено таблиц: {len(tables)}")
