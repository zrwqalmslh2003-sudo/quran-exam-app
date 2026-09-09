import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/data/content_manifest.dart';
import 'package:quran_exam_app/data/github_content_source.dart';
import 'package:quran_exam_app/data/manifest_service.dart';

/// ملاحظة: هذا الملف لا يهيّئ TestWidgetsFlutterBinding لأن الـ binding
/// يستبدل HttpClient فيرد 400 بلا شبكة فعلية على كل الطلبات.
/// مسار rootBundle (assets) غير مطلوب هنا؛ نُمرّر [ContentManifest] محلياً صراحةً.

const _local = ContentManifest(
  schemaVersion: 1,
  contentVersion: 1,
  exams: [
    ManifestExam(
      id: 'quran_qalon',
      version: 1,
      title: 'اختبارات قالون',
      file: 'exams/quran_qalon.json',
      sha256: '0000000000000000000000000000000000000000000000000000000000000000',
      questionCount: 520,
    ),
  ],
);

String manifestJson({int contentVersion = 2, int examVersion = 2}) =>
    jsonEncode({
      'schemaVersion': 1,
      'contentVersion': contentVersion,
      'updatedAt': '2026-09-09',
      'exams': [
        {
          'id': 'quran_qalon',
          'version': examVersion,
          'title': 'اختبارات قالون',
          'file': 'exams/quran_qalon.json',
          'sha256': '0000000000000000000000000000000000000000000000000000000000000000',
          'questionCount': 520,
        }
      ],
    });

void main() {
  late HttpServer server;
  late GithubContentSource source;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path;
      if (path.endsWith('/manifest.json')) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(manifestJson());
        await request.response.close();
        return;
      }
      if (path.endsWith('/manifest_bad_schema.json')) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'schemaVersion': 0,
            'contentVersion': 9,
            'exams': <Object?>[
              {
                'id': 'q',
                'version': 1,
                'title': 't',
                'file': 'exams/a.json',
                'sha256': '0000000000000000000000000000000000000000000000000000000000000000',
              }
            ],
          }));
        await request.response.close();
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
    source = GithubContentSource(
      owner: 'o',
      repo: 'r',
      baseUrl: 'http://${server.address.address}:${server.port}',
    );
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  group('GithubContentSource.fetchManifest', () {
    test('استجابة 200 → تحليل واعتماد', () async {
      final manifest = await source.fetchManifest();

      expect(manifest.schemaVersion, 1);
      expect(manifest.contentVersion, 2);
      expect(manifest.exams.single.id, 'quran_qalon');
      expect(manifest.exams.single.version, 2);
    });

    test('استجابة 404 → ContentFetchException بحالة 404', () async {
      await expectLater(
        source.fetchText(source.urlFor('missing.json')),
        throwsA(isA<ContentFetchException>()
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('محتوى مخالف للعقد → FormatException', () async {
      final bad = await source.fetchText(source.urlFor('manifest_bad_schema.json'));
      expect(
        () => ContentManifest.fromJson(jsonDecode(bad)),
        throwsFormatException,
      );
    });
  });

  group('ManifestService المقارنة مع البعيد', () {
    test('sha256 مفقود أو malformed يرفض manifest', () {
      final raw = {
        'schemaVersion': 1,
        'contentVersion': 2,
        'exams': [
          {
            'id': 'quran_qalon',
            'version': 2,
            'title': 'اختبارات قالون',
            'file': 'exams/quran_qalon.json',
            'sha256': 'not-a-hash',
          },
        ],
      };
      expect(() => ContentManifest.fromJson(raw), throwsFormatException);
    });

    test('isUpdateAvailable: أحدث ⇐ تحديث، متساوي/أقدم ⇐ بلا', () async {
      final remote = await source.fetchManifest(); // contentVersion 2
      expect(await ManifestService.isUpdateAvailable(remote, local: _local), isTrue);
      expect(
        await ManifestService.isUpdateAvailable(_local, local: _local),
        isFalse,
      );
    });

    test('remoteExamIfNewer: نسخة exam أحدث تُعاد، ومساوية لا تُعاد', () async {
      final remote = await source.fetchManifest(); // exam version 2

      final newer =
          await ManifestService.remoteExamIfNewer(remote, examId: 'quran_qalon', local: _local);
      expect(newer, isNotNull);
      expect(newer!.version, 2);

      expect(
        await ManifestService.remoteExamIfNewer(_local, examId: 'quran_qalon', local: _local),
        isNull,
        reason: 'نسخة مساوية لا تعتبر تحديثاً',
      );
    });

    test('exam غير معروف ⇒ null', () async {
      final remote = await source.fetchManifest();
      expect(
        await ManifestService.remoteExamIfNewer(remote, examId: 'nope', local: _local),
        isNull,
      );
    });

    test('schemaVersion مختلف ⇒ FormatException', () async {
      const bad = ContentManifest(
        schemaVersion: 2,
        contentVersion: 2,
        exams: [
          ManifestExam(
            id: 'quran_qalon',
            version: 9,
            title: 'اختبارات قالون',
            file: 'exams/quran_qalon.json',
            sha256: '0000000000000000000000000000000000000000000000000000000000000000',
          ),
        ],
      );
      expect(
        () => ManifestService.isUpdateAvailable(bad, local: _local),
        throwsFormatException,
      );
      expect(
        () => ManifestService.remoteExamIfNewer(bad, examId: 'quran_qalon', local: _local),
        throwsFormatException,
      );
    });
  });
}
