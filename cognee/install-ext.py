"""Поставить расширение json для графового движка (kuzu/ladybug).

Пробуем помощник cognee, затем прямой INSTALL через сам движок.
Скрипт не валит сборку: итог виден в /opt/ext-install.log.
"""
import traceback

ok = False

try:
    from cognee_db_workers._kuzu_helpers import install_json_extension_local
    install_json_extension_local()
    print("помощник cognee: успех")
    ok = True
except Exception:
    print("помощник cognee не сработал:")
    traceback.print_exc()

if not ok:
    for mod, ctor in (("ladybug", "Database"), ("kuzu", "Database")):
        try:
            m = __import__(mod)
            db = getattr(m, ctor)(":memory:")
            conn = m.Connection(db)
            conn.execute("INSTALL JSON")
            conn.execute("LOAD JSON")
            print(f"{mod}: INSTALL JSON выполнен")
            ok = True
            break
        except Exception:
            print(f"{mod}: не вышло")
            traceback.print_exc()

if not ok:
    # Кеш уже разложен из репозитория — пробуем загрузить файл напрямую.
    import glob
    for path in glob.glob("/data-seed/.*/extension/*/*/json/libjson.*"):
        try:
            import ladybug as m
            db = m.Database(":memory:")
            conn = m.Connection(db)
            conn.execute(f"LOAD EXTENSION '{path}'")
            print("загрузка файлом:", path)
            ok = True
            break
        except Exception:
            print("не вышло загрузить", path)
            traceback.print_exc()

import os
print("разложенные файлы:")
for root, _dirs, files in os.walk("/data-seed"):
    for f in files:
        print("  ", os.path.join(root, f))

print("ИТОГ:", "установлено" if ok else "НЕ УСТАНОВЛЕНО")
