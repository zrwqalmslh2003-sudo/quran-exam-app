import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/data/content_manifest.dart';
import 'package:quran_exam_app/data/manifest_service.dart';

Map<String, Object?> _noDupFixture() => {
      'id': 'quran_qalon',
      'version': 3,
      'title': 'اختبارات قالون',
      'file': 'exams/quran_qalon.json',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('manifest المضمّن', () {
    test('يُحمَّل من الأصول ويلتزم بالعقد', () async {
      final manifest = await ManifestService.loadLocal();

      expect(manifest.schemaVersion, 1);
      expect(manifest.contentVersion, greaterThanOrEqualTo(1));
      expect(manifest.exams, isNotEmpty);

      for (final exam in manifest.exams) {
        expect(exam.id, isNotEmpty);
        expect(exam.version, greaterThanOrEqualTo(1));
        expect(exam.title, isNotEmpty);
        expect(exam.file, matches(r'^[A-Za-z0-9_./-]+\.json$'));
      }
    });

    test('إعادة التسلسل للحفْظ لا تفقد شيئاً', () async {
      final manifest = await ManifestService.loadLocal();
      final round = ContentManifest.fromJson(manifest.toJson());

      expect(round.schemaVersion, manifest.schemaVersion);
      expect(round.contentVersion, manifest.contentVersion);
      expect(round.exams.length, manifest.exams.length);
      expect(round.exams.first.toJson(), manifest.exams.first.toJson());
    });
  });

  group('تحقق العقد (FormatException)', () {
    ContentManifest good() => ContentManifest.fromJson({
          'schemaVersion': 1,
          'contentVersion': 2,
          'exams': [
            {
              'id': 'quran_qalon',
              'version': 3,
              'title': 'اختبارات قالون',
              'file': 'exams/quran_qalon.json',
            }
          ],
        });

    test('schemaVersion خاطئ يُرفض', () {
      expect(
        () => ContentManifest.fromJson({
          'schemaVersion': 0,
          'contentVersion': 1,
          'exams': good().toJson()['exams'],
        }),
        throwsFormatException,
      );
    });

    test('exams فارغة تُرفض', () {
      expect(
        () => ContentManifest.fromJson({
          'schemaVersion': 1,
          'contentVersion': 1,
          'exams': <Object?>[],
        }),
        throwsFormatException,
      );
    });

    test('معرف مكرر يُرفض', () {
      final exam = _noDupFixture();
      expect(
        () => ContentManifest.fromJson({
          'schemaVersion': 1,
          'contentVersion': 1,
          'exams': [exam, exam],
        }),
        throwsFormatException,
      );
    });

    test('version صفر أو مسار خاطئ يُرفضان', () {
      expect(
        () => ContentManifest.fromJson({
          'schemaVersion': 1,
          'contentVersion': 1,
          'exams': [
            {
              'id': 'q',
              'version': 0,
              'title': 't',
              'file': 'exams/a.json',
            }
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => ContentManifest.fromJson({
          'schemaVersion': 1,
          'contentVersion': 1,
          'exams': [
            {
              'id': 'q',
              'version': 1,
              'title': 't',
              'file': 'exams/a.txt',
            }
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('مقارنة الإصدارات', () {
    test('isNewerThan فقط للنسخ الأحدث', () async {
      final manifest = await ManifestService.loadLocal();
      final exam = manifest.exams.first;

      expect(exam.isNewerThan(exam.version + 5), isFalse, reason: 'البعيد أحدث');
      expect(exam.isNewerThan(exam.version), isFalse, reason: 'متساوي');
      expect(exam.isNewerThan(exam.version - 1), isTrue, reason: 'المحلي أحدث');
    });
  });
}