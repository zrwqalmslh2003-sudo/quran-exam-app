import 'dart:convert';
import 'dart:io';

import 'content_manifest.dart';

/// خطأ جلب محتوى بعيد — يُميّز فشل الشبكة/الكود غير 200.
class ContentFetchException implements Exception {
  ContentFetchException(this.message, {this.statusCode, this.url});

  final String message;
  final int? statusCode;
  final String? url;

  @override
  String toString() => 'ContentFetchException: $message';
}

/// مصدر محتوى من GitHub عبر `raw.githubusercontent.com` بلا إضافات
/// (dart:io HttpClient فقط).
///
/// ملاحظة v1.4 (جزء 1): الجلب فقط — مَن يقرّر فعلاً تفعيل نسخة محلية هو
/// UpdateManager (لاحقاً)؛ الكود هنا لا يكتب أي شيء.
class GithubContentSource {
  GithubContentSource({
    required this.owner,
    required this.repo,
    this.branch = 'main',
    this.baseUrl,
  });

  /// اسم الحساب/المنظمة في GitHub.
  final String owner;

  /// اسم مستودع المحتوى.
  final String repo;

  /// الفرع الافتراضي للمحتوى (raw.githubusercontent.com).
  final String branch;

  /// أساس الرابط — سلوكيًا تُرك ويرجع لـ raw مباشرة،
  /// وتُستخدم في الاختبارات مع خادم محلي.
  final String? baseUrl;

  static const _defaultBase = 'https://raw.githubusercontent.com';

  /// عنوان ملف المانفيست/الاختبار في المستودع:
  /// `https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}`.
  Uri urlFor(String path, {String? branch}) {
    final base = baseUrl ?? _defaultBase;
    return Uri.parse('$base/$owner/$repo/${branch ?? this.branch}/$path');
  }

  static const _timeout = Duration(seconds: 15);

  /// يجلب نص الملف ويعيده؛ أي استجابة غير 200 ترمى [ContentFetchException].
  Future<String> fetchText(Uri url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(_timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw ContentFetchException(
          'فشل جلب المحتوى (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
          url: url.toString(),
        );
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  /// يجلب `manifest.json` ويحلّله مع التحقق من العقد.
  Future<ContentManifest> fetchManifest() async {
    final raw = await fetchText(urlFor('manifest.json'));
    return ContentManifest.fromJson(jsonDecode(raw));
  }
}