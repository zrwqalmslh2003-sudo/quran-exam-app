#!/usr/bin/env python3
"""
تحويل قاعدة SQLite للتطبيق إلى ملف بيانات JSON واحد.

التطبيق يعتمد الآن على JSON بدلاً من SQLite (قبول FlutLab لملفات .json).

الاستخدام:
    python3 tools/sqlite_to_json.py [SRC.sqlite] [DST.json]
افتراضياً: SRC = assets/app_data.sqlite  و DST = assets/app_data.json
"""
import json
import sqlite3
import sys


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 else "assets/app_data.sqlite"
    dst = sys.argv[2] if len(sys.argv) > 2 else "assets/app_data.json"

    con = sqlite3.connect(src)
    try:
        tables = [r[0] for r in con.execute(
            "SELECT name FROM sqlite_master WHERE type='table'")]
        out = {}
        for t in tables:
            cols = [r[1] for r in con.execute(f'PRAGMA table_info("{t}")')]
            rows = [dict(zip(cols, row)) for row in con.execute(
                f'SELECT * FROM "{t}"')]
            out[t] = rows
    finally:
        con.close()

    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))

    import os
    print("تم التحويل:", dst, f"{os.path.getsize(dst)/1024/1024:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())