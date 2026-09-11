# Qalon Web MVP (Web-1)

عميل ويب مستقل لتطبيق قالون، موجود بالكامل داخل مجلد `web/` وعلى فرع `manus/web-app`. لا يستبدل تطبيق Flutter ولا يعدّل SQLite أو عقد المحتوى القائم.

## التشغيل

```bash
cd web
pnpm install
pnpm dev
```

مصدر المحتوى الافتراضي هو مستودع GitHub العام:
`https://raw.githubusercontent.com/zrwqalmslh2003-sudo/quran-exam-app-content/main`.
يمكن تغييره دون تعديل الكود:

```bash
VITE_CONTENT_BASE_URL=https://example.invalid/content pnpm dev
```

## الاختبارات والبناء

```bash
pnpm test
pnpm build
pnpm preview
```

طبقة `src/content/repository.ts` مسؤولة عن الجلب، وطبقة `src/domain/content.ts`
مسؤولة عن التحقق، حل شجرة التصنيفات، أهلية العشوائية، وحساب النتيجة. الواجهة
لا تفسر JSON مباشرة.

## المزايا

يدعم Web-1 تحميل manifest والاختبارات، التنقل العربي RTL من الصفحة الرئيسية إلى
التصنيفات والاختبار، وعرض أنواع `single_choice` و`multiple_choice` و`true_false`
و`ayah`. يعرض حالات التحميل، الشبكة، JSON التالف، نوع السؤال غير المدعوم،
والقائمة الفارغة. النتيجة وحالة الاختبار محليتان لجلسة المتصفح.

تحترم العشوائية العامة `includeInRandom`: القيمة المفقودة أو `false` تستبعد
الاختبار، ولا يُقبل الاختبار إلا مع category محلولة. لا توجد مصادقة أو قاعدة
بيانات أو مفاتيح سرية أو تحليلات في Web-1.

## القيود المعروفة

المستودع البعيد الحالي لا يضع `categoryId` أو `newCategoryName` لكل عنصر؛ لذلك
يُستخدم حقل `category` الموجود كمرجع عرض متوافق. لا توجد حسابات مستخدمين أو
مزامنة نتائج أو لوحة إدارة، ولا تُنفذ أنواع الأسئلة المحجوزة غير الموجودة في
العقد الحالي.
