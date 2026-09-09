import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/data/app_data.dart';
import 'package:quran_exam_app/data/sqlite_exam_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Directory _tmpDir() => Directory.systemTemp.createTempSync('qalon_remote_test');

Future<SQLiteExamRepository> _openRepo(Directory dir, String name) =>
    SQLiteExamRepository.open(
        factory: databaseFactoryFfi, path: '${dir.path}/$name.db');

const _quranGeneralPayload = '''
{
  "schemaVersion": 1,
  "id": "quran_general",
  "version": 1,
  "title": "القرآن الكريم — أسئلة عامة",
  "questions": [
    {"id": "q1", "type": "single_choice", "prompt": "أول ما نزل من القرآن؟", "options": ["الفاتحة", "العلق", "البقرة", "المسد"], "correctAnswer": 1, "explanation": "سورة العلق."},
    {"id": "q2", "type": "single_choice", "prompt": "كم عدد سور القرآن؟", "options": ["112", "114", "116", "118"], "correctAnswer": 1},
    {"id": "q3", "type": "single_choice", "prompt": "أطول سورة في القرآن؟", "options": ["آل عمران", "البقرة", "النساء", "المائدة"], "correctAnswer": 1}
  ]
}
''';

Future<void> _activate(SQLiteExamRepository repo) async {
  await repo.storeRemoteExam('quran_general', 1, _quranGeneralPayload);
  await repo.activateRemoteExam('quran_general', 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('randomQuestions تستخدم الاختبار البعيد النشط (quran_general)', () async {
    final dir = _tmpDir();
    addTearDown(() => dir.deleteSync(recursive: true));
    final repo = await _openRepo(dir, 'app');
    addTearDown(repo.close);
    await _activate(repo);

    final qs = await repo.randomQuestions(10);
    expect(qs.map((q) => q.text).toSet(), {
      'أول ما نزل من القرآن؟',
      'كم عدد سور القرآن؟',
      'أطول سورة في القرآن؟',
    });
    for (final q in qs) {
      expect(q.options.length, greaterThanOrEqualTo(2));
      expect(q.correctOptionId, inInclusiveRange(0, q.options.length - 1));
      expect(q.correctOptionIds, [q.correctOptionId]);
      expect(q.allowsMultiple, isFalse);
      expect(q.points, 1);
    }
  });

  test('randomQuestions تعود للمصدر المضمّن عند غياب اختبار بعيد نشط', () async {
    final dir = _tmpDir();
    addTearDown(() => dir.deleteSync(recursive: true));
    final repo = await _openRepo(dir, 'app');
    addTearDown(repo.close);

    final store = await AppDataStore.instance;
    final qs = await repo.randomQuestions(5);
    expect(qs, isNotEmpty);
    expect(qs.length, 5);
    final localTexts = store.table('questions').map((r) => r['text']).toSet();
    for (final q in qs) {
      expect(localTexts.contains(q.text), isTrue,
          reason: 'أي سؤال يجب أن يأتي من المصدر المحلي المضمّن');
    }
  });

  test('حمولة بعيدة تالفة → تراجع آمن للمصدر المضمّن دون حذف الصف', () async {
    final dir = _tmpDir();
    addTearDown(() => dir.deleteSync(recursive: true));
    final repo = await _openRepo(dir, 'app');
    addTearDown(repo.close);
    await repo.storeRemoteExam('quran_general', 1, 'ليست JSON حقيقية');
    await repo.activateRemoteExam('quran_general', 1);

    final qs = await repo.randomQuestions(5);
    expect(qs, isNotEmpty);
    expect(qs.every((q) => q.text.isNotEmpty), isTrue);
    expect(await repo.remoteExamVersion('quran_general'), 1,
        reason: 'يُبقي النسخة النشطة فعالة بعد الفشل الآمن');
  });

  test('questionsForTopic تبقى محلية حتى مع اختبار بعيد نشط', () async {
    final dir = _tmpDir();
    addTearDown(() => dir.deleteSync(recursive: true));
    final repo = await _openRepo(dir, 'app');
    addTearDown(repo.close);
    await _activate(repo);

    final store = await AppDataStore.instance;
    final expected = store.questionsOfTopic(1).map((q) => q.text).toSet();
    final actual = (await repo.questionsForTopic(1)).map((q) => q.text).toSet();
    expect(actual, isNotEmpty);
    expect(actual, expected);
  });

  test('ayahExam يبقى محلياً مبنياً على الآيات مع اختبار بعيد نشط', () async {
    final dir = _tmpDir();
    addTearDown(() => dir.deleteSync(recursive: true));
    final repo = await _openRepo(dir, 'app');
    addTearDown(repo.close);
    await _activate(repo);

    final ayah = await repo.ayahExam(1, limit: 5);
    expect(ayah, isNotEmpty);
    expect(ayah.length, 5);
    for (final q in ayah) {
      expect(q.options.length, 4);
      expect(q.correctIndex, inInclusiveRange(0, 3));
    }
  });
}