/// مصدر صفوف جدول — يُنفَّذ من ملفات JSON المضمّنة ([AppDataStore])
/// أو من قاعدة SQLite ([SQLiteExamRepository]).
abstract class TableSource {
  List<Map<String, Object?>> table(String name);
}