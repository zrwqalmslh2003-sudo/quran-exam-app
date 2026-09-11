import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'content_manifest.dart';
import 'github_content_source.dart';
import 'sqlite_exam_repository.dart';

/// Minimal diagnostic sink. It must not receive question contents or secrets.
typedef UpdateDiagnostic = void Function(String event);

/// مدير التحديث — يجلب المانفيست البعيد، يتحقق من كل المحتوى المطلوب، ثم
/// يفعّل المجموعة كوحدة واحدة مع الحفاظ على النسخة السابقة عند الفشل.
class UpdateManager {
  const UpdateManager._();

  static const _kManifestContentVersion = 'manifest_content_version';
  static const _maxExamPayloadBytes = 8 * 1024 * 1024;
  static const _maxQuestions = 5000;
  static const _maxPromptLength = 4000;
  static const _maxExplanationLength = 12000;
  static const _maxOptions = 12;
  static const _maxOptionLength = 1000;

  /// يفحص التحديثات وينفذها إن وُجدت. يظل سلوك الفشل صامتًا بالنسبة للواجهة.
  static Future<void> checkForUpdates({
    required GithubContentSource source,
    required SQLiteExamRepository repo,
    UpdateDiagnostic? onDiagnostic,
  }) async {
    try {
      final remoteManifest = await source.fetchManifest();
      final localVersionStr = await repo.manifestMetaValue(
        _kManifestContentVersion,
      );
      final localContentVersion = int.tryParse(localVersionStr ?? '') ?? 0;

      if (remoteManifest.contentVersion <= localContentVersion) {
        onDiagnostic?.call('no_update');
        return;
      }

      _validateHierarchyReferences(repo, remoteManifest.exams);

      final staged = <RemoteExamPayload>[];
      for (final exam in remoteManifest.exams) {
        final localVersion = await repo.remoteExamVersion(exam.id);
        if (localVersion != null && !exam.isNewerThan(localVersion)) continue;
        staged.add(await _stageExam(source, exam));
      }

      await repo.applyRemoteUpdate(
        exams: staged,
        contentVersion: remoteManifest.contentVersion,
      );
      onDiagnostic?.call('updated');
    } catch (error) {
      // Startup must remain resilient. Record only a coarse category and keep
      // the previous active content untouched.
      onDiagnostic?.call(_categoryFor(error));
    }
  }

  static Future<RemoteExamPayload> _stageExam(
    GithubContentSource source,
    ManifestExam remoteExam,
  ) async {
    final bytes = await source.fetchBytes(
      source.urlFor(remoteExam.file),
      maxBytes: _maxExamPayloadBytes,
    );
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash.toLowerCase() != remoteExam.sha256) {
      throw const FormatException('بصمة SHA-256 لا تطابق المانفيست');
    }
    final raw = utf8.decode(bytes);
    if (raw.length > _maxExamPayloadBytes) {
      throw const FormatException('حمولة الاختبار تتجاوز الحجم المسموح');
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Exam payload يجب أن يكون كائناً JSON');
    }
    if (decoded['schemaVersion'] != 1) {
      throw const FormatException('schemaVersion غير مدعوم في حمولة الاختبار');
    }
    if (decoded['id'] != remoteExam.id) {
      throw const FormatException('معرّف الاختبار لا يطابق المانفيست');
    }
    if (decoded['version'] != remoteExam.version) {
      throw const FormatException('نسخة الاختبار لا تطابق المانفيست');
    }

    final questions = decoded['questions'];
    if (questions is! List || questions.isEmpty) {
      throw const FormatException('حمولة الاختبار بلا أسئلة');
    }
    if (questions.length > _maxQuestions) {
      throw const FormatException('عدد أسئلة الاختبار يتجاوز الحد المسموح');
    }
    for (final question in questions) {
      _validateQuestion(question);
    }
    if (remoteExam.questionCount != null &&
        remoteExam.questionCount != questions.length) {
      throw const FormatException('عدد الأسئلة لا يطابق المانفيست');
    }

    return RemoteExamPayload(
      examId: remoteExam.id,
      version: remoteExam.version,
      payload: raw,
      categoryId: remoteExam.categoryId,
      subcategoryId: remoteExam.subcategoryId,
      newCategoryName: remoteExam.newCategoryName,
      newSubcategoryName: remoteExam.newSubcategoryName,
      includeInRandom: remoteExam.includeInRandom ?? false,
    );
  }

  static void _validateHierarchyReferences(
    SQLiteExamRepository repo,
    List<ManifestExam> exams,
  ) {
    final categories = repo.table('categories')
        .where((row) => row['is_active'] == 1)
        .map((row) => row['id'])
        .whereType<int>()
        .toSet();
    final subcategories = <int, int>{};
    for (final row in repo.table('subcategories')) {
      final id = row['id'];
      final parent = row['category_id'];
      if (row['is_active'] == 1 && id is int && parent is int) {
        subcategories[id] = parent;
      }
    }
    for (final exam in exams) {
      final categoryExists = exam.categoryId != null && categories.contains(exam.categoryId);
      if (exam.categoryId != null && !categoryExists && exam.newCategoryName == null) {
        throw FormatException('مرجع categoryId غير موجود للاختبار ${exam.id}');
      }
      if (exam.subcategoryId != null) {
        final parent = subcategories[exam.subcategoryId];
        if (parent == null && exam.newSubcategoryName == null) {
          throw FormatException('مرجع subcategoryId غير موجود للاختبار ${exam.id}');
        }
        if (parent != null && exam.categoryId != null && categoryExists && parent != exam.categoryId) {
          throw FormatException('علاقة category/subcategory غير صالحة للاختبار ${exam.id}');
        }
      }
      if (exam.newSubcategoryName != null &&
          exam.categoryId == null &&
          exam.newCategoryName == null &&
          exam.subcategoryId == null) {
        throw FormatException('الـsubcategory الجديد بلا category أب للاختبار ${exam.id}');
      }
      if (exam.includeInRandom == true &&
          exam.categoryId == null &&
          exam.newCategoryName == null &&
          exam.subcategoryId == null) {
        throw FormatException(
            'includeInRandom يتطلب مرجع category صالح للاختبار ${exam.id}');
      }
    }
  }

  static void _validateQuestion(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('سؤال بعيد تالف');
    }
    final question = raw.cast<Object?, Object?>();
    final id = question['id'];
    final prompt = question['prompt'];
    final options = question['options'];
    final correct = question['correctAnswer'];
    if (id is! String || id.isEmpty || id.length > 200) {
      throw const FormatException('معرف السؤال غير صالح');
    }
    if (prompt is! String || prompt.isEmpty || prompt.length > _maxPromptLength) {
      throw const FormatException('نص السؤال غير صالح أو طويل جدًا');
    }
    if (options is! List ||
        options.length < 2 ||
        options.length > _maxOptions ||
        options.any((item) =>
            item is! String || item.isEmpty || item.length > _maxOptionLength)) {
      throw const FormatException('خيارات السؤال غير صالحة');
    }
    if (correct is! int || correct < 0 || correct >= options.length) {
      throw const FormatException('الإجابة الصحيحة غير صالحة');
    }
    final explanation = question['explanation'];
    if (explanation != null &&
        (explanation is! String || explanation.length > _maxExplanationLength)) {
      throw const FormatException('شرح السؤال غير صالح أو طويل جدًا');
    }
  }

  static String _categoryFor(Object error) {
    if (error is ContentFetchException) return 'http_failure';
    if (error is FormatException) return 'validation_failure';
    return 'storage_or_network_failure';
  }
}
