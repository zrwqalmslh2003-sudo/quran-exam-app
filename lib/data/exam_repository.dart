import '../models/question.dart';
import 'app_data.dart';
import 'quran_gen.dart';
import 'sqlite_exam_repository.dart';

/// واجهة مصدر الأسئلة — محرك الاختبار لا يعرف من أين جاءت الأسئلة
/// (JSON محلي، SQLite، GitHub، مستقبلاً API).
abstract class ExamRepository {
  static ExamRepository? _instance;

  /// المصدر الافتراضي: SQLite بعد التهيئة الأولية،
  /// مع الاحتياط إلى JSON المضمّن عند فشل الفتح/القراءة.
  static Future<ExamRepository> get instance async {
    if (_instance != null) return _instance!;
    try {
      _instance = await SQLiteExamRepository.open();
      return _instance!;
    } catch (_) {
      _instance = LocalExamRepository(await AppDataStore.instance);
      return _instance!;
    }
  }

  /// أسئلة موضوع معيّن.
  Future<List<Question>> questionsForTopic(int topicId);

  /// أسئلة عشوائية موزّعة على التصنيفات.
  Future<List<Question>> randomQuestions(int count, {int? categoryId});

  /// اختبار آيات مولّد (الآية → أي سورة؟) ضمن ربع معيّن، حتى الحد المطلوب.
  Future<List<AyahQuestion>> ayahExam(int quarterId, {required int limit});
}

/// مصدر محلي — يقرأ من ملفات JSON المضمّنة في الحزمة.
/// يُستخدم كـ bootstrap/fallback لصالح [SQLiteExamRepository].
class LocalExamRepository implements ExamRepository {
  final AppDataStore store;
  QuranGenerator? _generator;

  LocalExamRepository(this.store);

  @override
  Future<List<Question>> questionsForTopic(int topicId) async =>
      store.questionsOfTopic(topicId);

  @override
  Future<List<Question>> randomQuestions(int count, {int? categoryId}) async =>
      store.randomQuestions(count, categoryId: categoryId);

  @override
  Future<List<AyahQuestion>> ayahExam(int quarterId,
          {required int limit}) async =>
      buildAyahExam(_generator ??= QuranGenerator(store), quarterId,
          limit: limit);
}