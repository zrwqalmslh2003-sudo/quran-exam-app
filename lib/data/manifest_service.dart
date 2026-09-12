import 'dart:convert';

import 'package:flutter/services.dart';

import 'content_manifest.dart';

/// خدمة المانفيست — تحميل فهرس المحتوى والتحقق منه.
///
/// محلياً: [loadLocal] يقرأ المانفيست المضمّن من `assets/manifest.json`.
/// بعيداً: يُسلَّم [ContentManifest] (من [GithubContentSource]) إلى
/// [isUpdateAvailable]/[remoteExamIfNewer] للمقارنة مع المضمّن
/// دون كتابة أي شيء — قرار التفعيل من اختصاص UpdateManager (v1.4/2).
class ManifestService {
  static const _localPath = 'assets/manifest.json';

  /// يُحمّل المانفيست المضمّن مع التحقق من العقد.
  /// يرمي [FormatException] إذا كان المحتوى مخالفاً للعقد.
  static Future<ContentManifest> loadLocal() async {
    final raw = await rootBundle.loadString(_localPath);
    return ContentManifest.fromJson(jsonDecode(raw));
  }

  /// هل الفهرس البعيد أحدث من المضمّن؟
  ///
  /// يرمي [FormatException] إذا اختلف `schemaVersion` (كسر عقد يتطلب تحديث التطبيق،
  /// لا تحديث محتوى). [local] تُحقن في الاختبارات بدل `assets/manifest.json`.
  static Future<bool> isUpdateAvailable(
    ContentManifest remote, {
    ContentManifest? local,
  }) async {
    local ??= await loadLocal();
    _guardSameSchema(local, remote);
    return remote.contentVersion > local.contentVersion;
  }

  /// الـ exam الأحدث من البعيد لمعرّف [examId] إن وُجد، وإلا `null`.
  ///
  /// - لم يُعثر عليه محلياً أو بعيدياً → `null`.
  /// - نسخة بعيدة أحدث (أو امتداد جديد) → تُعاد.
  /// - نسخة بعيدة مساوية/أقدم → `null`.
  /// - اختلاف `schemaVersion` → [FormatException].
  static Future<ManifestExam?> remoteExamIfNewer(
    ContentManifest remote, {
    required String examId,
    ContentManifest? local,
  }) async {
    local ??= await loadLocal();
    _guardSameSchema(local, remote);

    final remoteExam = manifestById(remote, examId);
    if (remoteExam == null) return null;

    final localExam = manifestById(local, examId);
    if (localExam == null || remoteExam.isNewerThan(localExam.version)) {
      return remoteExam;
    }
    return null;
  }

  static ManifestExam? manifestById(ContentManifest manifest, String id) {
    for (final exam in manifest.exams) {
      if (exam.id == id) return exam;
    }
    return null;
  }

  static void _guardSameSchema(ContentManifest local, ContentManifest remote) {
    if (remote.schemaVersion != local.schemaVersion) {
      throw FormatException(
        'schemaVersion لا يطابق: المحلي ${local.schemaVersion} والبعيد '
        '${remote.schemaVersion} — تحديث المحتوى لا يكفي، يلزم تحديث التطبيق',
      );
    }
  }
}