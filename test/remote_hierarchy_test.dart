import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/data/app_data.dart';
import 'package:quran_exam_app/data/exam_repository.dart';
import 'package:quran_exam_app/data/sqlite_exam_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Directory _tmpDir() => Directory.systemTemp.createTempSync('qalon_hierarchy');

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

Future<SQLiteExamRepository> _openRepo(Directory dir,
    {bool bootstrap = true}) async {
  final fallback = LocalExamRepository(await AppDataStore.instance);
  return SQLiteExamRepository.open(
    factory: databaseFactoryFfi,
    path: '${dir.path}/app.db',
    bootstrap: bootstrap,
    fallback: fallback,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  group('references حتمية', () {
    test('اسم جديد → remote:c والـ subcategory ترث أباً حتمياً', () async {
      final dir = _tmpDir();
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = await _openRepo(dir);
      addTearDown(repo.close);

      await repo.applyRemoteUpdate(
        exams: [
          _exam('exam_a', newCategoryName: 'علوم القرآن',
              newSubcategoryName: 'مبادئ التجويد'),
        ],
        contentVersion: 2,
      );

      final rows = await repo.remoteHierarchyRows();
      expect(rows.single.categoryReference, 'remote:c:علوم_القرآن');
      expect(rows.single.subcategoryReference,
          'remote:sc:remote:c:علوم_القرآن:مبادئ_التجويد');

      final tree = await repo.remoteCategoryTree();
      expect(tree, hasLength(1));
      expect(tree.single.name, 'علوم القرآن');
      expect(tree.single.subcategories.single.name, 'مبادئ التجويد');
      expect(await repo.questionsForExam('exam_a'), hasLength(1));
    });

    test('مرجع محلي بالمعرّف → local:c / local:sc بلا إنشاء remote', () async {
      final dir = _tmpDir();
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = await _openRepo(dir);
      addTearDown(repo.close);

      await repo.applyRemoteUpdate(
        exams: [_exam('local_exam', categoryId: 1, subcategoryId: 1)],
        contentVersion: 2,
      );

      final rows = await repo.remoteHierarchyRows();
      expect(rows.single.categoryReference, 'local:c:1');
      expect(rows.single.subcategoryReference, 'local:sc:1');

      final tree = await repo.remoteCategoryTree();
      expect(tree, isEmpty,
          reason: 'مراجع local لا تُنشئ remote categories في الشجرة البعيدة');
    });

    test('اسم جديد مطابق لمحلي → يحل للمحلي دون تكرار', () async {
      final dir = _tmpDir();
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = await _openRepo(dir);
      addTearDown(repo.close);

      await repo.applyRemoteUpdate(
        exams: [_exam('name_collision', newCategoryName: 'أصول الرواية')],
        contentVersion: 2,
      );

      final rows = await repo.remoteHierarchyRows();
      expect(rows.single.categoryReference, 'local:c:1',
          reason: 'اسم "أصول الرواية" محلي (id=1) → لا duplicate');

      final tree = await repo.remoteCategoryTree();
      expect(tree, isEmpty,
          reason: 'الاسم المطابق لمحلي لا يُنشئ remote category');
    });

    test('تكرار الاسم الجديد في نفس المانفيست → reference واحد', () async {
      final dir = _tmpDir();
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = await _openRepo(dir);
      addTearDown(repo.close);

      await repo.applyRemoteUpdate(
        exams: [
          _exam('exam_b1', newCategoryName: 'التجويد', newSubcategoryName: 'المدود'),
          _exam('exam_b2', newCategoryName: 'التجويد', newSubcategoryName: 'المدود'),
        ],
        contentVersion: 2,
      );

      final tree = await repo.remoteCategoryTree();
      expect(tree, hasLength(1), reason: 'category مكرر → صف واحد');
      expect(tree.single.subcategories, hasLength(1),
          reason: 'subcategory مكرر → صف واحد');
      expect(tree.single.examIds, isEmpty);
      expect(tree.single.subcategories.single.examIds, hasLength(2));
    });
  });

  group('سلامة التخزين', () {
    test('لا exam نشط بلا mapping', () async {
      final dir = _tmpDir();
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = await _openRepo(dir);
      addTearDown(repo.close);

      await repo.applyRemoteUpdate(
        exams: [
          // exam بلا أي metadata أيضاً يجب أن يملك صف hierarchy (مراجع null)
          _exam('plain_exam'),
        ],
        contentVersion: 2,
      );

      final rows = await repo.remoteHierarchyRows();
      expect(rows, hasLength(1));
      expect(rows.single.categoryReference, isNull);
      expect(rows.single.subcategoryReference, isNull);
    });

    test('الجداول المحلية لا تتعدّل بعد تحديث بعيد', () async {
      final dir = _tmpDir();
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = await _openRepo(dir);
      addTearDown(repo.close);

      final localCategories = repo.table('categories').length;
      final localSubcategories = repo.table('subcategories').length;
      final localTopics = repo.table('topics').length;
      final localQuestions = repo.table('questions').length;

      await repo.applyRemoteUpdate(
        exams: [
          _exam('new_cat_exam', newCategoryName: 'علوم جديدة'),
        ],
        contentVersion: 2,
      );

      expect(repo.table('categories').length, localCategories);
      expect(repo.table('subcategories').length, localSubcategories);
      expect(repo.table('topics').length, localTopics);
      expect(repo.table('questions').length, localQuestions);
      expect((await repo.questionsForTopic(1)), isNotEmpty,
          reason: 'المحتوى المحلي سليم وقابل للقراءة');
    });

    test('atomicity: فشل كتابة hierarchy أثناء تحديث → تراجع كامل', () async {
      final dir = _tmpDir();
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = await _openRepo(dir);
      addTearDown(repo.close);

      // trigger يرفض أي صف hierarchy لـ 'boom_exam' → يكسر المعاملة.
      // ملاحظة: sameInstance على نفس المسار → `db` هو اتصال الـ repo نفسه،
      // لذا لا نغلقه هنا (يُغلق عند addTearDown(repo.close)).
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
            _exam('good_exam', newCategoryName: 'علوم جديدة'),
            _exam('boom_exam', newCategoryName: 'علوم أخرى'),
          ],
          contentVersion: 2,
        ),
        throwsA(anything),
      );

      expect(await repo.remoteExamVersion('good_exam'), isNull,
          reason: 'تراجع كامل: لا exam سليم مخزّن بعد فشل الأخير');
      expect(await repo.remoteHierarchyRows(), isEmpty,
          reason: 'لا صف شجرة جزئي');
      expect(await repo.remoteCategoryTree(), isEmpty);
      expect(await repo.manifestMetaValue('manifest_content_version'), isNull);
    });
  });

  group('دمج الشجرة البعيدة في الملاحة (Step 3)', () {
    test('category وsubcategory بعيدتان جديدتان → بيانات تصفح كاملة', () async {
      final dir = _tmpDir();
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = await _openRepo(dir);
      addTearDown(repo.close);

      await repo.applyRemoteUpdate(
        exams: [
          _exam('exam_n', newCategoryName: 'علوم جديدة',
              newSubcategoryName: 'فرع جديد'),
        ],
        contentVersion: 2,
      );

      final tree = await repo.remoteCategoryTree();
      expect(tree.single.reference, 'remote:c:علوم_جديدة');

      final subs =
          await repo.remoteSubcategoriesFor('remote:c:علوم_جديدة');
      expect(subs, hasLength(1));
      expect(subs.single.reference, 'remote:sc:remote:c:علوم_جديدة:فرع_جديد');
      expect(subs.single.examIds, ['exam_n']);

      expect(await repo.remoteExamsForCategory('remote:c:علوم_جديدة'), isEmpty,
          reason: 'الاختبار تحت subcategory لا يظهر كاختبار مباشر للتصنيف');

      final direct =
          await repo.remoteExamsForSubcategory(subs.single.reference);
      expect(direct, hasLength(1));
      expect(direct.single.id, 'exam_n');
      expect(direct.single.title, 'اختبار exam_n');
      expect(direct.single.questionCount, 1);
    });

    test('مراجع local حقيقية → الاختبار يظهر داخل subcategory المحلية فقط',
        () async {
      final dir = _tmpDir();
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = await _openRepo(dir);
      addTearDown(repo.close);

      await repo.applyRemoteUpdate(
        exams: [
          _exam('local_d1', categoryId: 1, subcategoryId: 1),
          _exam('local_d2', categoryId: 1),
        ],
        contentVersion: 2,
      );

      final underSub = await repo.remoteExamsForSubcategory('local:sc:1');
      expect(underSub.map((e) => e.id), ['local_d1']);
      expect(underSub.single.title, 'اختبار local_d1');

      final underCat = await repo.remoteExamsForCategory('local:c:1');
      expect(underCat.map((e) => e.id), ['local_d2'],
          reason: 'العزل: الاختبار الملتصق بـ subcategory لا يظهر مباشرة للتصنيف');

      expect(await repo.remoteSubcategoriesFor('local:c:1'), isEmpty,
          reason: 'لا فرع بعيد جديد تحت تصنيف محلي هنا');
      expect(await repo.remoteCategoryTree(), isEmpty,
          reason: 'المحتوى المحلي الجذر لا يُنشئ remote categories');
    });

    test('subcategory بعيدة بلا إنشاء category → تُدمج تحت التصنيف المحلي',
        () async {
      final dir = _tmpDir();
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = await _openRepo(dir);
      addTearDown(repo.close);

      await repo.applyRemoteUpdate(
        exams: [
          _exam('local_sub_new', categoryId: 1,
              newSubcategoryName: 'فرع محلي جديد'),
        ],
        contentVersion: 2,
      );

      final subs = await repo.remoteSubcategoriesFor('local:c:1');
      expect(subs, hasLength(1));
      expect(subs.single.reference, 'remote:sc:local:c:1:فرع_محلي_جديد');
      expect(subs.single.examIds, ['local_sub_new']);

      final direct = await repo.remoteExamsForSubcategory(subs.single.reference);
      expect(direct.single.id, 'local_sub_new');

      expect(await repo.remoteExamsForCategory('local:c:1'), isEmpty,
          reason: 'الاختبار ملتصق بالفرع الجديد لا بالتصنيف مباشرة');
      expect(await repo.remoteCategoryTree(), isEmpty,
          reason: 'الأب محلي → لا category بعيدة تُنشأ');
    });

    test('اختباران متعددان → entries حسب التفعيل وعزل questionsForExam', () async {
      final dir = _tmpDir();
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = await _openRepo(dir);
      addTearDown(repo.close);

      await repo.applyRemoteUpdate(
        exams: [
          _exam('multi_a', newCategoryName: 'التعليم', newSubcategoryName: 'أساسيات'),
          _exam('multi_b', newCategoryName: 'التعليم', newSubcategoryName: 'أساسيات'),
        ],
        contentVersion: 2,
      );

      const subRef = 'remote:sc:remote:c:التعليم:أساسيات';
      final entries = await repo.remoteExamsForSubcategory(subRef);
      expect(entries.map((e) => e.id).toSet(), {'multi_a', 'multi_b'});
      expect(entries.every((e) => e.questionCount == 1), isTrue);

      final catEntries = await repo.remoteExamsForCategory('remote:c:التعليم');
      expect(catEntries, isEmpty);

      expect((await repo.questionsForExam('multi_a')).single.text,
          'سؤال multi_a؟');
      expect((await repo.questionsForExam('multi_b')).single.text,
          'سؤال multi_b؟');
    });
  });

  group('ترقية المخطط', () {
    test('onUpgrade من v1 → v2 ينشئ جداول hierarchy', () async {
      final dir = _tmpDir();
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/app.db';

      // قاعدة v1 قديمة: أعمدة كاملة لما يقرأه الكود في الترقية.
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 1),
      );
      await old.execute(
          'CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT, emoji TEXT, sort_order INTEGER, is_active INTEGER)');
      await old.execute(
          'CREATE TABLE subcategories (id INTEGER PRIMARY KEY, category_id INTEGER, name TEXT, emoji TEXT, sort_order INTEGER, is_active INTEGER)');
      for (final name in const [
        'topics', 'questions', 'chapters', 'verses', 'tafseer',
      ]) {
        await old.execute('CREATE TABLE $name (id INTEGER)');
      }
      await old.execute(
          'CREATE TABLE remote_exams (exam_id TEXT NOT NULL, version INTEGER NOT NULL, payload TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 0, activated_at TEXT, created_at TEXT NOT NULL, UNIQUE(exam_id, version))');
      await old.execute('CREATE TABLE content_meta (key TEXT PRIMARY KEY, value TEXT)');
      await old.close();

      final repo = await SQLiteExamRepository.open(
        factory: databaseFactoryFfi,
        path: path,
        bootstrap: false,
        fallback: LocalExamRepository(await AppDataStore.instance),
      );
      addTearDown(repo.close);

      // بعد الترقية تصبح الكتابة في الشجرة البعيدة ممكنة (الجداول وُجدت).
      await repo.applyRemoteUpdate(
        exams: [_exam('migrated_exam', newCategoryName: 'بعد الترقية')],
        contentVersion: 2,
      );
      final tree = await repo.remoteCategoryTree();
      expect(tree.single.name, 'بعد الترقية');
    });
  });
}