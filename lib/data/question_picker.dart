import 'dart:math';

import '../models/question.dart';

/// خوارزمية اختيار الأسئلة العشوائية الموزّعة بين التصنيفات
/// (منطق `get_random_questions` الأصلي) — يتشاركها المصدران:
/// ملفات JSON المضمّنة و SQLite.
class QuestionPicker {
  QuestionPicker._();

  static List<Question> pick({
    required List<Map<String, Object?>> categories,
    required List<Map<String, Object?>> subcategories,
    required List<Map<String, Object?>> topics,
    required List<Map<String, Object?>> questions,
    required int count,
    int? categoryId,
    Random? random,
  }) {
    final rand = random ?? Random();

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

    final eligibleQuestions = questions.where(eligible).toList();

    if (categoryId != null) {
      final pool = eligibleQuestions.where((q) => categoryOf(q) == categoryId).toList()
        ..shuffle(rand);
      return pool.take(count).map(Question.fromRow).toList();
    }

    final avail = <int, int>{};
    for (final q in eligibleQuestions) {
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
      final pool = eligibleQuestions.where((q) => categoryOf(q) == cats[i]).toList()
        ..shuffle(rand);
      for (final r in pool.take(limit)) {
        out.add(Question.fromRow(r));
        usedIds.add(r['id'] as int);
      }
    }

    if (out.length < target) {
      final fill = eligibleQuestions
          .where((q) => !usedIds.contains(q['id']))
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
