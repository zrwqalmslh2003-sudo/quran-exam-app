import '../models/question.dart';
import 'app_data.dart';
import 'quran_gen.dart';

/// واجهة مصدر الأسئلة — محرك الاختبار لا يعرف من أين جاءت الأسئلة
/// (JSON محلي، SQLite، GitHub، مستقبلاً API).
abstract class ExamRepository {
  static ExamRepository? _instance;

  /// النسخة الافتراضية فوق البيانات المضمّنة في الحزمة.
  static Future<ExamRepository> get instance async =>
      _instance ??= LocalExamRepository(await AppDataStore.instance);

  /// أسئلة موضوع معيّن.
  Future<List<Question>> questionsForTopic(int topicId);

  /// أسئلة عشوائية موزّعة على التصنيفات.
  Future<List<Question>> randomQuestions(int count, {int? categoryId});

  /// اختبار آيات مولّد (الآية → أي سورة؟) ضمن ربع معيّن، حتى الحد المطلوب.
  Future<List<AyahQuestion>> ayahExam(int quarterId, {required int limit});
}

/// مصدر محلي — يقرأ من ملفات JSON المضمّنة في الحزمة.
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