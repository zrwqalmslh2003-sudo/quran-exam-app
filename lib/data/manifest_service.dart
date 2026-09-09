import 'dart:convert';

import 'package:flutter/services.dart';

import 'content_manifest.dart';

/// خدمة المانفيست — تحميل فهرس المحتوى والتحقق منه.
///
/// في هذه المرحلة (v1.3) لا يجلب التطبيق أي شيء من الشَبكة؛
/// يقرأ [loadLocal] المانفيست المضمّن من `assets/manifest.json`
/// ويرفض خللاً في العقد. الجلب من GitHub ومقارنة النسخ الفعلي خارجي
/// من مقرر v1.4.
class ManifestService {
  static const _localPath = 'assets/manifest.json';

  /// يُحمّل المانفيست المضمّن مع التحقق من العقد.
  /// يرمي [FormatException] إذا كان المحتوى مخالفاً للعقد.
  static Future<ContentManifest> loadLocal() async {
    final raw = await rootBundle.loadString(_localPath);
    return ContentManifest.fromJson(jsonDecode(raw));
  }
}