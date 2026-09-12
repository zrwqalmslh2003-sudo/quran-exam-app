import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/data/exam_repository.dart';
import 'package:quran_exam_app/data/github_content_source.dart';
import 'package:quran_exam_app/data/quran_gen.dart';
import 'package:quran_exam_app/data/sqlite_exam_repository.dart';
import 'package:quran_exam_app/data/update_manager.dart';
import 'package:quran_exam_app/models/question.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// اختبار تكاملي ضد GitHub الحقيقي — إثبات أن التطبيق يجلب ويخزّن
/// ويفعّل اختباراً جديداً من مستودع المحتوى البعيد.
///
/// يُتخطى افتراضياً، ويُفعَّل عبر:
/// flutter test --dart-define=RUN_INTEGRATION=true test/integration_github_update_test.dart
const _owner = 'zrwqalmslh2003-sudo';
const _repo = 'quran-exam-app-content';
const _examId = 'quran_general';

const _runIntegration = bool.fromEnvironment('RUN_INTEGRATION');

class _StubRepository implements ExamRepository {
  @override
  Future<List<AyahQuestion>> ayahExam(int quarterId,
          {required int limit}) async =>
      const [];

  @override
  Future<List<Question>> questionsForTopic(int topicId) async => const [];

  @override
  Future<List<Question>> randomQuestions(int count, {int? categoryId}) async =>
      const [];
}

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'جلب→تحقق→تخزين→تفعيل اختبار جديد من GitHub الحقيقي',
    skip: _runIntegration
        ? null
        : 'تكاملية: مرر --dart-define=RUN_INTEGRATION=true',
    () async {
      final dir = Directory.systemTemp.createTempSync('qalon_e2e');
      addTearDown(() => dir.deleteSync(recursive: true));

      final repo = await SQLiteExamRepository.open(
        factory: databaseFactoryFfi,
        path: '${dir.path}/app.db',
        fallback: _StubRepository(),
        bootstrap: false,
      );
      addTearDown(repo.close);

      final source = GithubContentSource(owner: _owner, repo: _repo);

      await UpdateManager.checkForUpdates(source: source, repo: repo);

      final version = await repo.remoteExamVersion(_examId);
      expect(version, isNotNull, reason: 'يجب تفعيل الاختبار البعيد الجديد');
      expect(version, greaterThanOrEqualTo(1));

      final meta =
          await repo.manifestMetaValue('manifest_content_version');
      expect(meta, isNotNull, reason: 'يُسجَّل contentVersion بعد نجاح كامل');

      // فحص الصف المخزن — JSON النصي كما ورد (بلا تطبيع).
      final copy = '${dir.path}/snapshot.db';
      await File('${dir.path}/app.db').copy(copy);
      final db = await databaseFactoryFfi.openDatabase(copy);
      final rows = await db.query('remote_exams');
      await db.close();

      expect(rows, isNotEmpty);
      final qg = rows.where((r) => r['exam_id'] == _examId).toList();
      expect(qg, hasLength(1), reason: 'يُخزَّن quran_general مرة واحدة');
      expect(qg.single['is_active'], 1);
      final payload =
          jsonDecode(qg.single['payload'] as String) as Map<String, dynamic>;
      expect(payload['id'], _examId);
      expect((payload['questions'] as List), isNotEmpty);
    },
  );
}