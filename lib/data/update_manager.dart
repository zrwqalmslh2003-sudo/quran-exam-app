import 'dart:convert';

import 'content_manifest.dart';
import 'github_content_source.dart';
import 'sqlite_exam_repository.dart';

/// مدير التحديث — يجلب المانفيست البعيد، يقارن الإصدارات، يحمّل الاختبارات
/// ويُفعّلها ذرياً مع الحفاظ على النسخة السابقة حتى اكتمال العملية.
///
/// لا يُحجب واجهة المستخدم أبداً: لا محاذاة، لا حوار، لا رسوم متحركة.
/// الخطأ الصامت هو السلوك الافتراضي: إما نجاح كامل أو إبقاء النسخة السابقة.
class UpdateManager {
  const UpdateManager._();

  /// يفحص التحديثات وينفّذها إن وُجدت — يُستدعى بعد [runApp] فقط.
  ///
  /// لا يُعيق الواجهة أبداً: أي استثناء يُبتلع داخلياً وتبقى النسخة السابقة.
  static Future<void> checkForUpdates({
    required GithubContentSource source,
    required SQLiteExamRepository repo,
  }) async {
    try {
      final remoteManifest = await source.fetchManifest();
      final localVersionStr = await repo.manifestMetaValue(
        _kManifestContentVersion,
      );
      final localContentVersion = int.tryParse(localVersionStr ?? '') ?? 0;

      if (remoteManifest.contentVersion <= localContentVersion) return;

      for (final exam in remoteManifest.exams) {
        await _processExam(source, repo, exam);
      }

      await repo.setManifestMeta(
        _kManifestContentVersion,
        remoteManifest.contentVersion.toString(),
      );
    } catch (_) {
      // صامت تماماً — لا يحجب الواجهة ولا يكسر شيئاً.
      // النسخة السابقة تبقى سليمة.
    }
  }

  static const _kManifestContentVersion = 'manifest_content_version';

  /// يجلب الاختبار البعيد، يتحقق من العقد، يُخزّنه، ويُفعّله ذرياً.
  /// يرمي أي خطأ مما يبطل العملية ويترك النسخة السابقة.
  static Future<void> _processExam(
    GithubContentSource source,
    SQLiteExamRepository repo,
    ManifestExam remoteExam,
  ) async {
    final localVersion = await repo.remoteExamVersion(remoteExam.id);
    if (localVersion != null && !remoteExam.isNewerThan(localVersion)) return;

    final raw = await source.fetchText(source.urlFor(remoteExam.file));
    final payload = jsonDecode(raw);

    // تحقق من بنية المحتوى (العقد lens)
    if (payload is! Map<String, Object?>) {
      throw const FormatException('Exam payload يجب أن يكون كائناً JSON');
    }
    if (payload['schemaVersion'] != 1) {
      throw const FormatException('schemaVersion غير مدعوم في حمولة الاختبار');
    }
    if (payload['id'] != remoteExam.id) {
      throw const FormatException('معرّف الاختبار لا يطابق المانفيست');
    }
    if (payload['version'] != remoteExam.version) {
      throw const FormatException('نسخة الاختبار لا تطابق المانفيست');
    }
    final questions = payload['questions'];
    if (questions is! List || questions.isEmpty) {
      throw const FormatException('حمولة الاختبار بلا أسئلة');
    }

    await repo.storeRemoteExam(remoteExam.id, remoteExam.version, raw);
    await repo.activateRemoteExam(remoteExam.id, remoteExam.version);
  }
}