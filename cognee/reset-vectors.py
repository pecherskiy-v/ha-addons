"""Удалить векторные таблицы Cognee, когда меняется размерность эмбеддингов.

Cognee не пересоздаёт их сам: после смены модели он пытается класть вектор
другой длины и падает с «expected N dimensions». Свои таблицы он отличает
колонкой `vector`; наши таблицы агентов используют `embedding` и не трогаются.
"""
import asyncio
import os
import sys

import asyncpg


async def main() -> int:
    conn = await asyncpg.connect(
        user=os.environ["DB_USERNAME"], password=os.environ["DB_PASSWORD"],
        host=os.environ["DB_HOST"], port=int(os.environ["DB_PORT"]),
        database=os.environ["DB_NAME"], timeout=15,
    )
    try:
        rows = await conn.fetch("""
            SELECT c.table_name
            FROM information_schema.columns c
            JOIN information_schema.tables t
              ON t.table_schema = c.table_schema AND t.table_name = c.table_name
            WHERE c.table_schema = 'public'
              AND c.column_name = 'vector'
              AND t.table_type = 'BASE TABLE'
        """)
        names = [r["table_name"] for r in rows]
        if not names:
            print("векторных таблиц Cognee не найдено — нечего сбрасывать")
            return 0
        for name in names:
            await conn.execute(f'DROP TABLE IF EXISTS "{name}" CASCADE')
            print("удалена таблица", name)
        print(f"сброшено таблиц: {len(names)}")
        return 0
    finally:
        await conn.close()


sys.exit(asyncio.run(main()))
