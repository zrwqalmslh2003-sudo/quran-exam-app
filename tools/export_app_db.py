#!/usr/bin/env python3
"""
تصدير قاعدة بيانات التطبيق من قواعد البوت.
يقرأ bot_data.db و quran.db ويخرج assets/app_data.sqlite
بالجداول المطلوبة فقط لتطبيق أندرويد.

الاستخدام:
    python3 tools/export_app_db.py [--src SRC_DIR] [--out DEST]
افتراضياً: المصدر = مجلد البوت ../myexambot، الملف الناتج = assets/app_data.sqlite
"""
import argparse
import os
import shutil
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BOT_TABLES = ["categories", "subcategories", "topics", "questions"]
QURAN_TABLES = ["chapters", "verses", "tafseer"]


def copy_table(src: sqlite3.Connection, dst: sqlite3.Connection, table: str,
               table_rename: str | None = None,
               drop_columns: tuple[str, ...] = ()) -> int:
    info = src.execute(f"PRAGMA table_info({table})").fetchall()
    keep_idx = [i for i, c in enumerate(info) if c[1] not in drop_columns]
    cols = [info[i][1] for i in keep_idx]
    rows = list(src.execute(f"SELECT * FROM {table}"))
    cols_sql = ", ".join(f'"{c}"' for c in cols)
    placeholders = ", ".join("?" for _ in cols)
    dst.execute(f'CREATE TABLE "{table_rename or table}" ({cols_sql})')
    dst.executemany(
        f'INSERT INTO "{table_rename or table}" ({cols_sql}) VALUES ({placeholders})',
        [tuple(r[i] for i in keep_idx) for r in rows],
    )
    return len(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description="توليد قاعدة بيانات التطبيق")
    parser.add_argument("--src", default=os.path.normpath(os.path.join(ROOT, "..", "myexambot")),
                        help="مجلد بوت المصدر (يحتوي bot_data.db و quran.db)")
    parser.add_argument("--out", default=os.path.join(ROOT, "assets", "app_data.sqlite"),
                        help="مسار ملف المخرجات")
    args = parser.parse_args()

    bot_db_path = os.path.join(args.src, "bot_data.db")
    quran_db_path = os.path.join(args.src, "quran.db")

    if not os.path.exists(bot_db_path) or not os.path.exists(quran_db_path):
        print(f"خطأ: لم يتم العثور على قواعد المصدر في {args.src}", file=sys.stderr)
        return 1

    if os.path.exists(args.out):
        os.remove(args.out)
    os.makedirs(os.path.dirname(args.out), exist_ok=True)

    src = sqlite3.connect(bot_db_path)
    src2 = sqlite3.connect(quran_db_path)
    dst = sqlite3.connect(args.out)
    try:
        src.row_factory = None
        total = {}
        for t in BOT_TABLES:
            drop = ("question_photo", "options_photos") if t == "questions" else ()
            total[t] = copy_table(src, dst, t, drop_columns=drop)
        for t in QURAN_TABLES:
            total[t] = copy_table(src2, dst, t)
        dst.commit()
    finally:
        src.close()
        src2.close()
        dst.close()

    size_mb = os.path.getsize(args.out) / (1024 * 1024)
    print("تم الإنشاء:", args.out)
    for t, n in total.items():
        print(f"  {t}: {n} صف")
    print(f"الحجم: {size_mb:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())