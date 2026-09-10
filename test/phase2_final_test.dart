import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/data/app_data.dart';
import 'package:quran_exam_app/data/exam_repository.dart';
import 'package:quran_exam_app/data/sqlite_exam_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// اختبارات Step 5 — هويات حقيقية فوق المحتوى المحلي المضمّن (bootstrap حقيقي):
/// - quran_general, ghareeb_quran, ahkam_noon_sakinah
/// - تصنيف/فرع محليان حقيقيان: category 5 «غريب القرآن» و subcategory 7 «الجزء الثلاثون»
///
/// لا توجد شبكة هنا إطلاقاً: كل الكتابة عبر `applyRemoteUpdate` فوق SQLite محلي.

Directory _tmpDir() => Directory.systemTemp.createTempSync('qalon_phase2_final');

String _payload(String examId, int version) => '''
{
  "schemaVersion": 1,
  "id": "$examId",
  "version": $version,
  "title": "اختبار $examId",
  "category": "quran",
  "questions": [{
    "id": "$examId-q1",
    "type": "single_choice",
    "prompt": "سؤال $examId؟",
    "options": ["أ", "ب"],
    "correctAnswer": 0
  }]
}''';

RemoteExamPayload _exam(
  String id, {
  int version = 1,
  int? categoryId,
  int? subcategoryId,
  String? newCategoryName,
  String? newSubcategoryName,
}) {
  return RemoteExamPayload(
    examId: id,
    version: version,
    payload: _payload(id, version),
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    newCategoryName: newCategoryName,
    newSubcategoryName: newSubcategoryName,
  );
}

Future<SQLiteExamRepository> _openRepo(Directory dir) async {
  final fallback = LocalExamRepository(await AppDataStore.instance);
  return SQLiteExamRepository.open(
    factory: databaseFactoryFfi,
    path: '${dir.path}/app.db',
    bootstrap: true,
    fallback: fallback,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  late SQLiteExamRepository repo;

  setUp(() async {
    dir = _tmpDir();
    addTearDown(() => dir.deleteSync(recursive: true));
    repo = await _openRepo(dir);
    addTearDown(repo.close);
  });

  test('manifest بهويات حقيقية: new + existing + عزل questionsForExam', () async {
    await repo.applyRemoteUpdate(
      exams: [
        _exam('quran_general', newCategoryName: 'القرآن',
            newSubcategoryName: 'عام'),
        _exam('ghareeb_quran', categoryId: 5, subcategoryId: 7),
        _exam('ahkam_noon_sakinah', newCategoryName: 'التجويد',
            newSubcategoryName: 'أحكام النون الساكنة'),
      ],
      contentVersion: 7,
    );

    expect(await repo.remoteExamVersion('quran_general'), 1);
    expect(await repo.remoteExamVersion('ghareeb_quran'), 1);
    expect(await repo.remoteExamVersion('ahkam_noon_sakinah'), 1);

    // تصنيفان بعيدان جديدان فقط — المحلي (غريب القرآن) لا ينشئ شجرة بعيدة.
    final tree = await repo.remoteCategoryTree();
    expect(tree.map((n) => n.name).toSet(), {'القرآن', 'التجويد'});
    expect(tree.every((n) => n.subcategories.single.examIds.single ==
            (n.name == 'القرآن' ? 'quran_general' : 'ahkam_noon_sakinah')),
        isTrue);

    // ghareeb_quran يظهر داخل subcategory محلية حقيقية: غريب القرآن ← الجزء الثلاثون.
    final localSub = await repo.remoteExamsForSubcategory('local:sc:7');
    expect(localSub.map((e) => e.id), ['ghareeb_quran']);
    expect(await repo.remoteExamsForCategory('local:c:5'), isEmpty,
        reason: 'الاختبار الملتصق بفرع محلي لا يظهر مباشرة عند التصنيف');

    // عزل محكم: كل اختبار يعيد سؤاله حرفياً ولا يُسرّب غيره.
    expect((await repo.questionsForExam('quran_general')).single.text,
        'سؤال quran_general؟');
    expect((await repo.questionsForExam('ghareeb_quran')).single.text,
        'سؤال ghareeb_quran؟');
    expect((await repo.questionsForExam('ahkam_noon_sakinah')).single.text,
        'سؤال ahkam_noon_sakinah؟');
    expect(await repo.questionsForExam('missing_exam'), isEmpty);

    final catalog = await repo.activeExamCatalog();
    expect(catalog.map((e) => e.id).toSet(),
        {'quran_general', 'ghareeb_quran', 'ahkam_noon_sakinah'});
    expect(catalog.every((e) => e.questionCount == 1), isTrue);
  });

  test('تصادم الاسم الجديد مع محلي → local:c بلا تكرار، واستخدام مكرر → صف واحد',
      () async {
    await repo.applyRemoteUpdate(
      exams: [
        _exam('quran_general', newCategoryName: 'أصول الرواية'),
        _exam('ghareeb_quran', newCategoryName: 'أصول الرواية'),
        _exam('ahkam_noon_sakinah', newCategoryName: 'التجويد'),
        _exam('tajweed_extra', newCategoryName: 'التجويد'),
      ],
      contentVersion: 8,
    );

    // "أصول الرواية" محلية (id=1) → كلاهما تحت المرجع المحلي بلا remote جديد.
    final underLocal = await repo.remoteExamsForCategory('local:c:1');
    expect(underLocal.map((e) => e.id).toSet(),
        {'quran_general', 'ghareeb_quran'});

    // "التجويد" الجديد مكرر في نفس المانفيست → تصنيف واحد باختبارين مباشرين.
    final tree = await repo.remoteCategoryTree();
    expect(tree, hasLength(1));
    expect(tree.single.reference, 'remote:c:التجويد');
    expect(tree.single.examIds.toSet(),
        {'ahkam_noon_sakinah', 'tajweed_extra'});
    expect(tree.single.subcategories, isEmpty);
  });

  test('تحديث لاحق فاشل ذرّياً → الشجرة السابقة والنسخة السابقة محفوظتان', () async {
    await repo.applyRemoteUpdate(
      exams: [
        _exam('quran_general', newCategoryName: 'القرآن',
            newSubcategoryName: 'عام'),
      ],
      contentVersion: 2,
    );
    expect(await repo.remoteCategoryTree(), hasLength(1));

    // trigger يرفض أي hierarchy لـ 'boom_exam' → يكسر معاملة التحديث الثاني.
    final db = await databaseFactoryFfi.openDatabase('${dir.path}/app.db');
    await db.execute('''
      CREATE TRIGGER deny_boom
      BEFORE INSERT ON remote_exam_hierarchy
      WHEN NEW.exam_id = 'boom_exam'
      BEGIN SELECT RAISE(ABORT, 'boom'); END
    ''');

    await expectLater(
      repo.applyRemoteUpdate(
        exams: [
          _exam('ghareeb_quran', categoryId: 5, subcategoryId: 7),
          _exam('boom_exam', newCategoryName: 'تجويد'),
        ],
        contentVersion: 3,
      ),
      throwsA(anything),
    );

    expect(await repo.remoteExamVersion('quran_general'), 1,
        reason: 'النشط السابق لم يُصَب بتراجع التحديث الفاشل');
    expect(await repo.remoteExamVersion('ghareeb_quran'), isNull);
    expect(await repo.remoteCategoryTree().then((t) => t.single.name),
        'القرآن', reason: 'شجرة التحديث الأول سليمة بعد فشل الثاني');
    expect(await repo.manifestMetaValue('manifest_content_version'), '2',
        reason: 'لا تقدم للنسخة الفاشلة');
  });

  test('توافق رجعي: exam بلا حقول hierarchy → مخزون ونشط لكن بلا شجرة بعيدة',
      () async {
    await repo.applyRemoteUpdate(
      exams: [_exam('legacy_exam')],
      contentVersion: 3,
    );

    expect(await repo.remoteExamVersion('legacy_exam'), 1);
    final rows = await repo.remoteHierarchyRows();
    expect(rows.single.categoryReference, isNull);
    expect(rows.single.subcategoryReference, isNull);
    expect(await repo.remoteCategoryTree(), isEmpty);
    expect(await repo.activeExamCatalog().then((c) => c.single.id),
        'legacy_exam');
  });

  test('انحدار محلي: تصنيفات ومواضيع محلية سليمة بعد تحديث بعيد', () async {
    final topics = repo.table('topics');
    expect(topics, isNotEmpty);
    final topicId = topics.first['id'] as int;
    final categoriesBefore = repo.table('categories').length;

    await repo.applyRemoteUpdate(
      exams: [
        _exam('quran_general', newCategoryName: 'القرآن',
            newSubcategoryName: 'عام'),
        _exam('ghareeb_quran', categoryId: 5, subcategoryId: 7),
        _exam('ahkam_noon_sakinah', newCategoryName: 'التجويد',
            newSubcategoryName: 'أحكام النون الساكنة'),
      ],
      contentVersion: 9,
    );

    expect(repo.table('categories').length, categoriesBefore,
        reason: 'التحديث البعيد لا يضيف للتصنيفات المحلية');
    expect(await repo.questionsForTopic(topicId), isNotEmpty,
        reason: 'أسئلة الموضوع المحلي قابلة للقراءة بعد التحديث البعيد');
    final local = await repo.questionsForTopic(topicId);
    expect(local.any((q) => q.text.contains('سؤال quran_general؟')), isFalse,
        reason: 'لا تسريب لأسئلة بعيدة في المواضيع المحلية');
  });
}