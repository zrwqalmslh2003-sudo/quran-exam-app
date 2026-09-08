import '../models/question.dart';
import 'app_data.dart';

/// واجهة البيانات القديمة — كل الاستعلامات تُحل الآن من ملفات JSON
/// عبر [AppDataStore] بدلاً من SQLite.
class AppDatabase {
  static Future<AppDataStore> get instance async =>
      AppDataStore.instance;

  static Future<List<Map<String, Object?>>> categories() async =>
      (await instance).activeCategories();

  static Future<List<Map<String, Object?>>> subcategories(int categoryId) async =>
      (await instance).subcategoriesOf(categoryId);

  /// مواضيع باب مع عدّاد الأسئلة المتاحة لكل موضوع.
  static Future<List<Map<String, Object?>>> topicsOfSubcategory(
          int subcategoryId) async =>
      (await instance).topicsOf(subcategoryId);

  static Future<String?> topicName(int topicId) async =>
      (await instance).topicNameFor(topicId);

  static Future<List<Question>> questionsForTopic(int topicId) async =>
      (await instance).questionsOfTopic(topicId);

  /// أسئلة عشوائية. `categoryId = null` يوزّع التناسب بين كل التصنيفات.
  static Future<List<Question>> randomQuestions(int count,
          {int? categoryId}) async =>
      (await instance).randomQuestions(count, categoryId: categoryId);
}