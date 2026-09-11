# Qalon Web MVP (Web-1)

عميل ويب مستقل لتطبيق قالون، موجود بالكامل داخل مجلد `web/` وعلى فرع `manus/web-app`. لا يستبدل تطبيق Flutter ولا يعدّل SQLite أو عقد المحتوى القائم.

## بنية web/

```
web/
├── src/
│   ├── App.tsx              # الجذر: الحالة، التنقل، الجلب، الجلسة، النتيجة
│   ├── content/
│   │   └── repository.ts    # جلب المحتوى من GitHub Raw
│   ├── domain/
│   │   └── content.ts       # الأنواع، التحقق، شجرة التصنيفات، حساب النتيجة
│   ├── storage/
│   │   ├── user.ts          # معرّف المستخدم المحلي
│   │   ├── session.ts       # جلسة الاختبار النشطة
│   │   └── results.ts       # آخر نتيجة محفوظة
│   ├── state/
│   │   └── router.ts        # hash-routing: parseHash / toHash / Route
│   ├── ui/
│   │   ├── components/      # Header, Notice, Answer, ExamProgress, StateViews
│   │   └── screens/         # HomeScreen, CategoriesScreen, CategoryScreen,
│   │                        # ExamScreen, ResultScreen (Result + ReviewResult)
│   └── tests/               # content, storage, integration, router, App (React)
├── package.json
├── vite.config.ts
└── tsconfig.json
```

## hash-routing

هناك خمس حالات مسار، تُقرأ وتُكتب عبر `src/state/router.ts`:

| المسار             | الحالة       |
|--------------------|--------------|
| `#/`               | الصفحة الرئيسية |
| `#/categories`     | قائمة التصنيفات |
| `#/category/<ref>` | تصنيف محدد (ref مفكوك الترميز) |
| `#/exam/<id>/<v>`  | اختبار محدد (id مفكوك الترميز مع النسخة) |
| `#/result`         | النتيجة / مراجعة آخر نتيجة |

- `parseHash` يطبّع أي hash غير معروف إلى `home` (لا صفحة بيضاء).
- التطبيق يستمع إلى `hashchange` و`popstate`، ويحفظ الجلسة قبل الإغلاق عبر `beforeunload`.
- عمق الروابط المباشرة يعمل: فتح `#/exam/<id>/<v>` يجد الاختبار في المانيفست ويجلبه تلقائيًا.

## تخزين النتائج والجلسة

- الجلسة النشطة: `localStorage['qalon.session.active']` — تُحفَظ مباشرة عند كل تغيير إجابة (بلا debounce).
- آخر نتيجة: `localStorage['qalon.result.last']` — نتيجة واحدة فقط، تتضمن أخطاء مع `correct`.
- معرّف المستخدم: `localStorage['qalon.user.id']` — يُنشأ مرة ويُعاد استخدامه.

## الاختبارات والبناء

```bash
pnpm install
pnpm test        # vitest (jsdom + node): content/storage/integration/router/App
pnpm build       # tsc --noEmit && vite build
pnpm preview
```

## مصدر المحتوى

المصدر الافتراضي هو مستودع GitHub العام:
`https://raw.githubusercontent.com/zrwqalmslh2003-sudo/quran-exam-app-content/main`.
يمكن تغييره دون تعديل الكود:

```bash
VITE_CONTENT_BASE_URL=https://example.invalid/content pnpm dev
```

طبقـة `src/content/repository.ts` مسؤولة عن الجلب، وطبقة `src/domain/content.ts`
مسؤولة عن التحقق، حل شجرة التصنيفات، أهلية العشوائية، وحساب النتيجة. الواجهة
لا تفسر JSON مباشرة.

## الدعم والقيود

- Web-1 يعرض نوع السؤال `single_choice` فقط؛ أي سؤال بنوع آخر غير مدعوم يظهر
  حالة `Unavailable` مع زر "العودة للتصنيفات" (لا تخمين، لا تجاوز، لا خطأ إحصائي).
- يعرض حالات التحميل، الشبكة، JSON التالف، والقائمة الفارغة.
- لا توجد مصادقة أو قاعدة بيانات أو مفاتيح سرية أو تحليلات في Web-1.

## خارج النطاق (Web-1)

- الاختبارات العشوائية، إدارة المحتوى، استيراد/إذاعة، التذكيرات، الإحالات.
- التحليلات، المصادقة/الحسابات، Telegram WebApp، مزامنة النتائج، لوحة إدارة.
- أنواع الأسئلة المحجوزة غير الموجودة في العقد الحالي لا تُنفذ إلا عند توفرها.

## القيود المعروفة

المستودع البعيد الحالي لا يضع `categoryId` أو `newCategoryName` لكل عنصر؛ لذلك
يُستخدم حقل `category` الموجود كمرجع عرض متوافق.