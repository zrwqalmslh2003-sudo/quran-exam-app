import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/data/content_manifest.dart';
import 'package:quran_exam_app/data/github_content_source.dart';
import 'package:quran_exam_app/data/manifest_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  late Uri base;
  late GithubContentSource source;

  String manifestJson({int schemaVersion = 1, int contentVersion = 2}) =>
      jsonEncode({
        'schemaVersion': schemaVersion,
        'contentVersion': contentVersion,
        'updatedAt': '2026-09-09',
        'exams': [
          {
            'id': 'quran_qalon',
            'version': 1,
            'title': 'اختبارات قالون',
            'file': 'exams/quran_qalon.json',
            'questionCount': 520,
          }
        ],
      });

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path.endsWith('/missing.json')) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      if (request.uri.path.endsWith('/manifest.json')) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(manifestJson());
        await request.response.close();
        return;
      }
      if (request.uri.path.endsWith('/manifest_bad_schema.json')) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(manifestJson(schemaVersion: 0));
        await request.response.close();
        return;
      }
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    });
    base = Uri.parse('http://${server.address.address}:${server.port}');
    source = GithubContentSource(owner: 'o', repo: 'r', baseUrl: base.toString());
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
    });

    test('استجابة 404 → ContentFetchException بحالة 404', () async {
      expect(
        () => source.fetchText(source.urlFor('missing.json')),
        throwsA(isA<ContentFetchException>()
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('محتوى مخالف للعقد → FormatException', () async {
      final bad = await source
          .fetchText(source.urlFor('manifest_bad_schema.json'));
      expect(
        () => ContentManifest.fromJson(jsonDecode(bad)),
        throwsFormatException,
      );
    });
  });

  group('ManifestService المقارنة مع البعيد', () {
    test('isUpdateAvailable: أحدث ⇐ بلا تحديث، متساوٍ ⇐ بلا', () async {
      final manifest = await source.fetchManifest(); // contentVersion 2
      final local = await ManifestService.loadLocal(); // contentVersion 1

      expect(manifest.contentVersion, isNot(local.contentVersion));
      expect(await ManifestService.isUpdateAvailable(manifest), isTrue);

      expect(await ManifestService.isUpdateAvailable(local), isFalse);
    });

    test('remoteExamIfNewer: نسخة exam أحدث تُعاد، ومساوية لا تُعاد', () async {
      final manifest = await source.fetchManifest();

      final newer = await ManifestService.remoteExamIfNewer(manifest,
          examId: 'quran_qalon');
      expect(newer, isNotNull);
      expect(newer!.version, greaterThanOrEqualTo(1));

      expect(
        await ManifestService.remoteExamIfNewer(
          await ManifestService.loadLocal(),
          examId: 'quran_qalon',
        ),
        isNull,
        reason: 'نسخة مساوية لا تعتبر تحديثاً',
      );
    });

    test('exam غير معروف ⇒ null', () async {
      final manifest = await source.fetchManifest();
      expect(
        await ManifestService.remoteExamIfNewer(manifest, examId: 'nope'),
        isNull,
      );
    });

    test('schemaVersion مختلف ⇒ FormatException', () async {
      // منظّم عقد v2 مستقبلي يُنتج schemaVersion أعلى؛ حارس ManifestService يرفضه.
      const bad = ContentManifest(
        schemaVersion: 2,
        contentVersion: 2,
        exams: [
          ManifestExam(
            id: 'quran_qalon',
            version: 9,
            title: 'اختبارات قالون',
            file: 'exams/quran_qalon.json',
          ),
        ],
      );
      expect(
        () => ManifestService.isUpdateAvailable(bad),
        throwsFormatException,
      );
      expect(
        () => ManifestService.remoteExamIfNewer(bad, examId: 'quran_qalon'),
        throwsFormatException,
      );
    });
  });
}