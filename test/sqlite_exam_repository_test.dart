import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/data/app_data.dart';
import 'package:quran_exam_app/data/exam_repository.dart';
import 'package:quran_exam_app/data/sqlite_exam_repository.dart';
import 'package:quran_exam_app/models/question.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

List<Question> _byId(List<Question> qs) {
  final copy = List<Question>.of(qs);
  copy.sort((a, b) => a.id.compareTo(b.id));
  return copy;
}

Directory _tmpDir() => Directory.systemTemp.createTempSync('qalon_test');

void main() {
  setUpAll(sqfliteFfiInit);

  test('bootstrap: SQLite مبني من JSON المضمّن يردّ نفس الأسئلة', () async {
    final dir = _tmpDir();
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.db';

    final store = await AppDataStore.instance;
    final expected = _byId(store.questionsOfTopic(1));

    final repo =
        await SQLiteExamRepository.open(factory: databaseFactoryFfi, path: path);
    addTearDown(repo.close);

    final actual = _byId(await repo.questionsForTopic(1));
    expect(actual.map((q) => q.text).toList(), expected.map((q) => q.text).toList());

    var total = 0;
    for (final t in store.table('topics')) {
      total += (await repo.questionsForTopic(t['id'] as int)).length;
    }
    expect(total, store.table('questions').length, reason: 'إجمالي 520 سؤالاً مهاجراً إلى SQLite');

    final ayah = await repo.ayahExam(1, limit: 15);
    expect(ayah.length, 15);
    for (final q in ayah) {
      expect(q.options.length, 4);
      expect(q.correctIndex, inInclusiveRange(0, 3));
    }
  });

  test('reopen: SQLite موجود لا يُعاد استيراده حتى لو اختلف JSON المضمّن', () async {
    final dir = _tmpDir();
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.db';

    final repo1 =
        await SQLiteExamRepository.open(factory: databaseFactoryFfi, path: path);
    final firstId = (await repo1.questionsForTopic(1)).first.id;
    await repo1.close();

    // تعديل مباشر على ملف القاعدة بعد التهيئة
    final raw = await databaseFactoryFfi.openDatabase(path);
    await raw.update('questions', {'text': 'SURVIVES-REOPEN'},
        where: 'id = ?', whereArgs: [firstId]);
    await raw.close();

    final repo2 =
        await SQLiteExamRepository.open(factory: databaseFactoryFfi, path: path);
    addTearDown(repo2.close);

    final restored =
        (await repo2.questionsForTopic(1)).firstWhere((q) => q.id == firstId);
    expect(restored.text, 'SURVIVES-REOPEN',
        reason: 'يجب ألا تُكتب نسخة JSON فوق تعديل SQLite عند إعادة الفتح');
  });

  test('empty sqlite: يُعاد التهيئة (bootstrap) تلقائياً إذا خلت القاعدة', () async {
    final dir = _tmpDir();
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.db';

    final repo1 =
        await SQLiteExamRepository.open(factory: databaseFactoryFfi, path: path);
    await repo1.close();

    final raw = await databaseFactoryFfi.openDatabase(path);
    await raw.delete('questions');
    await raw.close();

    final repo2 =
        await SQLiteExamRepository.open(factory: databaseFactoryFfi, path: path);
    addTearDown(repo2.close);

    expect(await repo2.questionsForTopic(1), isNotEmpty,
        reason: 'قاعدة فارغة → إعادة استيراد ناجحة');
  });

  test('تالف/فشل القراءة: الاحتياط إلى LocalExamRepository', () async {
    final dir = _tmpDir();
    addTearDown(() => dir.deleteSync(recursive: true));
    final fallback = LocalExamRepository(await AppDataStore.instance);

    // 1) ملف تالف لا يُفتح → نفس منطق ExamRepository.instance يقع على الاحتياط
    final bad = '${dir.path}/corrupt.db';
    File(bad).writeAsStringSync('this is not a sqlite database');
    ExamRepository chosen;
    try {
      chosen = await SQLiteExamRepository.open(factory: databaseFactoryFfi, path: bad);
    } catch (_) {
      chosen = fallback;
    }
    expect(await chosen.questionsForTopic(1), isNotEmpty);

    // 2) قاعدة صالحة ثم انغلاقها → القراءة تفشل وتُسجّل عبر الاحتياط
    final good = '${dir.path}/good.db';
    final repo =
        await SQLiteExamRepository.open(factory: databaseFactoryFfi, path: good);
    await repo.close();
    final afterClose = await repo.questionsForTopic(1);
    expect(afterClose, isNotEmpty,
        reason: 'فشل قراءة SQLite يجب أن يمرر إلى JSON المضمّن');
  });
}