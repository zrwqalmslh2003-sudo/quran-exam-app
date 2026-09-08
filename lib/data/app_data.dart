import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/question.dart';

/// مخزن البيانات في الذاكرة — يُحمّل ملفات JSON من الحزمة ثم يجيب
/// على الاستعلامات محلياً (بديل كامل عن SQLite).
class AppDataStore {
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
  List<Question> randomQuestions(int count, {int? categoryId}) {
    final rand = Random();
    final questions = table('questions');
    final topics = table('topics');
    final subcategories = table('subcategories');
    final categories = table('categories');

    final oFlat = <int, bool>{};
    final shapeCat = <int, bool>{};
    final topicOfSub = <int, int>{};
    final catOfSub = <int, int>{};

    for (final c in categories) {
      final id = c['id'];
      if (id is int) shapeCat[id] = c['is_active'] == 1;
    }
    for (final s in subcategories) {
      final id = s['id'];
      final c = s['category_id'];
      if (id is int && c is int) catOfSub[id] = c;
    }
    for (final t in topics) {
      final id = t['id'];
      final s = t['subcategory_id'];
      if (id is int && s is int) topicOfSub[id] = s;
      if (id is int) oFlat[id] = t['is_active'] == 1;
    }
    final subActive = <int, bool>{
      for (final s in subcategories)
        if (s['id'] is int) s['id'] as int: s['is_active'] == 1,
    };

    bool eligible(Map<String, Object?> q) {
      final options = q['options'];
      if (options is! String || options.isEmpty) return false;
      final t = q['topic_id'];
      if (t is! int || !(oFlat[t] ?? false)) return false;
      final s = topicOfSub[t];
      if (s == null || !(subActive[s] ?? false)) return false;
      final c = catOfSub[s];
      return c != null && (shapeCat[c] ?? false);
    }

    int? categoryOf(Map<String, Object?> q) {
      final t = q['topic_id'];
      if (t is! int) return null;
      final s = topicOfSub[t];
      if (s == null) return null;
      return catOfSub[s];
    }

    if (categoryId != null) {
      final pool = questions
          .where((q) => eligible(q) && categoryOf(q) == categoryId)
          .toList()
        ..shuffle(rand);
      return pool.take(count).map(Question.fromRow).toList();
    }

    final avail = <int, int>{};
    for (final q in questions) {
      if (!eligible(q)) continue;
      final c = categoryOf(q);
      if (c == null) continue;
      avail[c] = (avail[c] ?? 0) + 1;
    }
    if (avail.isEmpty) return [];

    final cats = avail.keys.toList()..shuffle(rand);
    final totalAvail = avail.values.fold<int>(0, (a, b) => a + b);
    final target = count < totalAvail ? count : totalAvail;
    final base = target ~/ cats.length;
    final remainder = target % cats.length;

    final out = <Question>[];
    final usedIds = <int>{};
    for (var i = 0; i < cats.length; i++) {
      var limit = base + (i < remainder ? 1 : 0);
      final available = avail[cats[i]]!;
      if (limit > available) limit = available;
      if (limit <= 0) continue;
      final pool = questions
          .where((q) => eligible(q) && categoryOf(q) == cats[i])
          .toList()
        ..shuffle(rand);
      for (final r in pool.take(limit)) {
        out.add(Question.fromRow(r));
        usedIds.add(r['id'] as int);
      }
    }

    if (out.length < target) {
      final fill = questions
          .where((q) {
            final options = q['options'];
            return options is String &&
                options.isNotEmpty &&
                !usedIds.contains(q['id']);
          })
          .toList()
        ..shuffle(rand);
      final need = target - out.length;
      for (final r in fill.take(need)) {
        out.add(Question.fromRow(r));
      }
    }
    return out;
  }
}