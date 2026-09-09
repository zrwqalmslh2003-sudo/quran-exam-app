import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/data/exam_repository.dart';
import 'package:quran_exam_app/data/github_content_source.dart';
import 'package:quran_exam_app/data/quran_gen.dart';
import 'package:quran_exam_app/data/sqlite_exam_repository.dart';
import 'package:quran_exam_app/data/update_manager.dart';
import 'package:quran_exam_app/models/question.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// ملاحظة: لا تهيئة لـ TestWidgetsFlutterBinding — الـ binding يستبدل HttpClient
/// فيرد 400 بلا شبكة فعلية. هنا نختبر بطلبات HTTP حقيقية ضد خادم محلي.

String examJson({
  String id = 'quran_qalon',
  int version = 2,
  int schemaVersion = 1,
}) {
  return jsonEncode({
    'schemaVersion': schemaVersion,
    'id': id,
    'version': version,
    'title': 'اختبارات قالون',
    'questions': [
      {
        'id': 'q1',
        'type': 'single_choice',
        'prompt': 'ما أول سورة؟',
        'options': ['الفاتحة', 'البقرة', 'آل عمران', 'النساء'],
        'correctAnswer': 0,
      },
    ],
  });
}

String manifestJson({
  int contentVersion = 2,
  int examVersion = 2,
  String? sha256Override,
}) {
  final payload = examJson(version: examVersion);
  return jsonEncode({
    'schemaVersion': 1,
    'contentVersion': contentVersion,
    'exams': [
      {
        'id': 'quran_qalon',
        'version': examVersion,
        'title': 'اختبارات قالون',
        'file': 'exams/quran_qalon.json',
        'sha256': sha256Override ?? sha256.convert(utf8.encode(payload)).toString(),
      }
    ],
  });
}

/// Fallback صامت — لا يستخدم في هذه الاختبارات (bootstrap: false).
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

  late HttpServer server;
  late Uri base;
  late GithubContentSource source;
  final routes = <String, String>{};

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final key = request.uri.path.split('/').last;
      final body = routes[key];
      if (body == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write(body);
      }
      await request.response.close();
    });
    base = Uri.parse('http://${server.address.address}:${server.port}');
    source = GithubContentSource(
      owner: 'o',
      repo: 'r',
      baseUrl: base.toString(),
    );
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  late Directory dir;
  late SQLiteExamRepository repo;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('qalon_update');
    addTearDown(() => dir.deleteSync(recursive: true));
    repo = await SQLiteExamRepository.open(
      factory: databaseFactoryFfi,
      path: '${dir.path}/app.db',
      fallback: _StubRepository(),
      bootstrap: false,
    );
    addTearDown(repo.close);
    routes.clear();
  });

  /// يفتح نسخة من الملف للتحقق من الصفوف — لأن إعادة فتح نفس المسار
  /// يعيد نفس الاتصال (singleInstance) وإغلاقه سيغلق اتصال الـ repo.
  Future<List<Map<String, Object?>>> rawRows(String table) async {
    final copy = '${dir.path}/_snapshot.db';
    await File('${dir.path}/app.db').copy(copy);
    final db = await databaseFactoryFfi.openDatabase(copy);
    final rows = await db.query(table);
    await db.close();
    return rows;
  }

  test('تشغيل أول: جلب → تحقق → تخزين → تفعيل + تحديث contentVersion', () async {
    routes['manifest.json'] = manifestJson(examVersion: 2);
    routes['quran_qalon.json'] = examJson(version: 2);

    await UpdateManager.checkForUpdates(source: source, repo: repo);

    expect(await repo.remoteExamVersion('quran_qalon'), 2);
    expect(
      await repo.manifestMetaValue('manifest_content_version'),
      '2',
    );
    final exams = await rawRows('remote_exams');
    expect(exams, hasLength(1));
    expect(exams.single['is_active'], 1);
    expect(jsonDecode(exams.single['payload'] as String)['version'], 2);
  });

  test('نفس contentVersion → لا عملية ولا تغيير', () async {
    routes['manifest.json'] = manifestJson(contentVersion: 5, examVersion: 2);
    routes['quran_qalon.json'] = examJson(version: 2);
    await UpdateManager.checkForUpdates(source: source, repo: repo);
    expect((await rawRows('remote_exams')), hasLength(1));

    routes['manifest.json'] = manifestJson(contentVersion: 5, examVersion: 2);
    await UpdateManager.checkForUpdates(source: source, repo: repo);

    expect((await rawRows('remote_exams')), hasLength(1));
    expect(await repo.remoteExamVersion('quran_qalon'), 2);
  });

  test('ترقية: نسخة أحدث تُفعَّل والقديمة تبقى مخزنة غير مفعّلة', () async {
    routes['manifest.json'] = manifestJson(contentVersion: 2, examVersion: 2);
    routes['quran_qalon.json'] = examJson(version: 2);
    await UpdateManager.checkForUpdates(source: source, repo: repo);

    routes['manifest.json'] = manifestJson(contentVersion: 3, examVersion: 3);
    routes['quran_qalon.json'] = examJson(version: 3);
    await UpdateManager.checkForUpdates(source: source, repo: repo);

    expect(await repo.remoteExamVersion('quran_qalon'), 3);
    final exams = await rawRows('remote_exams');
    expect(exams, hasLength(2));
    final active = exams.where((r) => r['is_active'] == 1).toList();
    expect(active, hasLength(1), reason: 'تفعيل ذري: نسخة مفعّلة واحدة فقط');
    expect(active.single['version'], 3,
        reason: 'النسخة المفعّلة يجب أن تكون الأحدث');
  });

  test('فشل جلب ملف الاختبار (404) → النسخة السابقة تبقى', () async {
    routes['manifest.json'] = manifestJson(contentVersion: 2, examVersion: 2);
    routes['quran_qalon.json'] = examJson(version: 2);
    await UpdateManager.checkForUpdates(source: source, repo: repo);

    // المانفيست يعرض تحديثاً لكن ملف الاختبار غير متوفر.
    routes['manifest.json'] = manifestJson(contentVersion: 3, examVersion: 3);
    routes.remove('quran_qalon.json');
    await UpdateManager.checkForUpdates(source: source, repo: repo);

    // لا يتغير شيء: لا توجد نسخة 3، والنسخة 2 مفعّلة، ولا تقدم للمانفيست بعد الفشل.
    expect(await repo.remoteExamVersion('quran_qalon'), 2);
    expect(await repo.manifestMetaValue('manifest_content_version'), '2',
        reason: 'يُجنّد الإصدار 3 في المانفيست فقط بعد نجاح كامل');
  });

  test('بصمة SHA-256 خاطئة → التحديث يُرفض والمحتوى السابق يبقى', () async {
    routes['manifest.json'] = manifestJson(examVersion: 2);
    routes['quran_qalon.json'] = examJson(version: 2);
    await UpdateManager.checkForUpdates(source: source, repo: repo);

    routes['manifest.json'] = manifestJson(
      contentVersion: 3,
      examVersion: 3,
      sha256Override:
          '0000000000000000000000000000000000000000000000000000000000000000',
    );
    routes['quran_qalon.json'] = examJson(version: 3);
    final diagnostics = <String>[];
    await UpdateManager.checkForUpdates(
      source: source,
      repo: repo,
      onDiagnostic: diagnostics.add,
    );

    expect(await repo.remoteExamVersion('quran_qalon'), 2);
    expect(await repo.manifestMetaValue('manifest_content_version'), '2');
    expect(diagnostics, ['validation_failure']);
  });

  test('حمولة مخالفة للعقد (schemaVersion) → رفض وتبقى السابقة', () async {
    routes['manifest.json'] = manifestJson(contentVersion: 2, examVersion: 2);
    routes['quran_qalon.json'] = examJson(version: 2);
    await UpdateManager.checkForUpdates(source: source, repo: repo);

    routes['manifest.json'] = manifestJson(contentVersion: 3, examVersion: 3);
    routes['quran_qalon.json'] = examJson(version: 3, schemaVersion: 2);
    await UpdateManager.checkForUpdates(source: source, repo: repo);

    expect(await repo.remoteExamVersion('quran_qalon'), 2);
    final exams = await rawRows('remote_exams');
    expect(exams, hasLength(1), reason: 'لم تُخزَّن النسخة المخالفة');
  });

  test('حمولة بـ id مخالف → رفض وتبقى السابقة', () async {
    routes['manifest.json'] = manifestJson(contentVersion: 2, examVersion: 2);
    routes['quran_qalon.json'] = examJson(version: 2);
    await UpdateManager.checkForUpdates(source: source, repo: repo);

    routes['manifest.json'] = manifestJson(contentVersion: 3, examVersion: 3);
    routes['quran_qalon.json'] = examJson(version: 3, id: 'other_exam');
    await UpdateManager.checkForUpdates(source: source, repo: repo);

    expect(await repo.remoteExamVersion('quran_qalon'), 2);
  });

  test('فشل المانفيست نفسه (الشبكة) → لا انهيار ولا تغيير', () async {
    routes['manifest.json'] = manifestJson(contentVersion: 3);
    routes['quran_qalon.json'] = examJson(version: 2);
    // نجعل المانفيست يتعذر: خادم يُغلق الاتصال.
    final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = dead.port;
    await dead.close(force: true);
    final deadSource = GithubContentSource(
      owner: 'o',
      repo: 'r',
      baseUrl: 'http://127.0.0.1:$deadPort',
    );

    await UpdateManager.checkForUpdates(source: deadSource, repo: repo);

    expect(await rawRows('remote_exams'), isEmpty);
    expect(await repo.manifestMetaValue('manifest_content_version'), null);
  });
}
