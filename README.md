# تطبيق اختبارات قالون - نسخة الأندرويد

تطبيق أندرويد مبني بـ Flutter لاختبارات قالون، مستوحى من بوت التيليجرام `myexambot`.
البناء يتم في GitHub Actions ولا يحتاج Flutter محلياً.

## البناء

1. عدّل قاعدة البيانات ثم أعد توليدها:
   ```bash
   python3 tools/export_app_db.py --src /storage/emulated/0/مشروعات/myexambot
   ```
2. ادفع التغييرات → `.github/workflows/build.yml` يبني `app-release.apk` تلقائياً
3. نزّل الـ APK من تبويب Actions (Artifact) أو من Release

## قاعدة البيانات

- `assets/app_data.sqlite` — تُدمج داخل الـ APK
- يُنشأ من `bot_data.db` + `quran.db` عبر `tools/export_app_db.py`
- عند أول تشغيل، يُنسخ إلى Documents ويُفتح بـ sqflite

## الهيكل

```
lib/
  main.dart           نقطة البداية
  data/db.dart        فتح القاعدة + استعلامات التصنيفات
  data/quran_gen.dart منطق "آية ← سورة" منقول من quran_database.py
  screens/            home / exam / ...
tools/export_app_db.py  توليد قاعدة التطبيق
```

## ملاحظة المنطق

`buildAyahQuestion` يعطي أول 3 خيارات من نفس الربع (أحزاب 1-15/16-30/31-45/46-60)
وإن نقص العدد لا يُنشأ السؤال — مطابق لسلوك البوت.