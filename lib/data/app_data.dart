import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/question.dart';
import 'question_picker.dart';
import 'table_source.dart';

/// مخزن البيانات في الذاكرة — يُحمّل ملفات JSON من الحزمة ثم يجيب
/// على الاستعلامات محلياً (بديل كامل عن SQLite).
class AppDataStore implements TableSource {
  static const _tables = [
    'categories',
    'subcategories',
    'topics',
    'questions',
    'chapters',
    'verses',
    'tafseer',
  ];

  static AppDataStore? _instance;

  final Map<String, List<Map<String, Object?>>> _data;

  AppDataStore._(this._data);

  static Future<AppDataStore> get instance async =>
      _instance ??= await load();

  static Future<AppDataStore> load() async {
    final data = <String, List<Map<String, Object?>>>{};
    for (final name in _tables) {
      final raw = await rootBundle.loadString('assets/$name.json');
      final list = (jsonDecode(raw) as List)
          .map((e) => (e as Map).map<String, Object?>(
              (k, v) => MapEntry(k, v)))
          .toList();
      data[name] = list;
    }
    return AppDataStore._(data);
  }

  List<Map<String, Object?>> table(String name) => _data[name]!;

  // ---- التصنيفات -----------------------------------------------------------

  List<Map<String, Object?>> activeCategories() => table('categories')
      .where((r) => r['is_active'] == 1)
      .toList()
    ..sort((a, b) =>
        (a['sort_order'] as int? ?? 0).compareTo(b['sort_order'] as int? ?? 0));

  List<Map<String, Object?>> subcategoriesOf(int categoryId) => table(
      'subcategories')
    .where((r) => r['category_id'] == categoryId && r['is_active'] == 1)
    .toList()
    ..sort((a, b) =>
        (a['sort_order'] as int? ?? 0).compareTo(b['sort_order'] as int? ?? 0));

  /// مواضيع باب مع عدّاد الأسئلة المتاحة لكل موضوع.
  List<Map<String, Object?>> topicsOf(int subcategoryId) {
    final counts = <int, int>{};
    for (final q in table('questions')) {
      final t = q['topic_id'];
      if (t is int) counts[t] = (counts[t] ?? 0) + 1;
    }
    final rows = table('topics')
        .where((r) => r['subcategory_id'] == subcategoryId && r['is_active'] == 1)
        .map((r) => {...r, 'qcount': counts[r['id']] ?? 0})
        .toList();
    rows.sort((a, b) => (a['id'] as int? ?? 0).compareTo(b['id'] as int? ?? 0));
    return rows;
  }

  String? topicNameFor(int topicId) {
    for (final t in table('topics')) {
      if (t['id'] == topicId) return t['name'] as String?;
    }
    return null;
  }

  // ---- أسئلة ----------------------------------------------------------------

  List<Question> questionsOfTopic(int topicId) {
    final rows = table('questions')
        .where((r) => r['topic_id'] == topicId)
        .toList()
      ..sort((a, b) => (a['question_order'] as int? ?? 0)
          .compareTo(b['question_order'] as int? ?? 0));
    return rows.map(Question.fromRow).toList();
  }

  /// أسئلة عشوائية. [categoryId] = null يوزّع التناسب بين كل التصنيفات
  /// (مطابق لمنطق `get_random_questions` الأصلي).
  List<Question> randomQuestions(int count, {int? categoryId}) =>
      QuestionPicker.pick(
        categories: table('categories'),
        subcategories: table('subcategories'),
        topics: table('topics'),
        questions: table('questions'),
        count: count,
        categoryId: categoryId,
      );
}