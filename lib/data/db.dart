import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import '../models/question.dart';

class AppDatabase {
  static Database? _db;

  /// Returns the app's SQLite database, copying `assets/app_data.json`
  /// (bundled under a FlutLab-friendly name) into the documents directory
  /// as `app_data.sqlite` on first run.
  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'app_data.sqlite');
    if (!await File(dbPath).exists()) {
      final data = await rootBundle.load('assets/app_data.json');
      await File(dbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    _db = await openDatabase(dbPath);
    return _db!;
  }

  // ---- التصنيفات -----------------------------------------------------------

  static Future<List<Map<String, Object?>>> categories() async {
    final db = await instance;
    return db.query('categories', where: 'is_active = 1', orderBy: 'sort_order');
  }

  static Future<List<Map<String, Object?>>> subcategories(int categoryId) async {
    final db = await instance;
    return db.query('subcategories',
        where: 'category_id = ? AND is_active = 1',
        whereArgs: [categoryId],
        orderBy: 'sort_order');
  }

  /// مواضيع باب مع عدّاد الأسئلة المتاحة لكل موضوع.
  static Future<List<Map<String, Object?>>> topicsOfSubcategory(
      int subcategoryId) async {
    final db = await instance;
    return db.rawQuery(
      'SELECT t.id, t.name, t.description, t.is_active, '
      '(SELECT COUNT(*) FROM questions q WHERE q.topic_id = t.id) AS qcount '
      'FROM topics t WHERE t.subcategory_id = ? AND t.is_active = 1 '
      'ORDER BY t.id',
      [subcategoryId],
    );
  }

  static Future<String?> topicName(int topicId) async {
    final db = await instance;
    final rows = await db.query('topics', where: 'id = ?', whereArgs: [topicId]);
    return rows.isEmpty ? null : rows.first['name'] as String?;
  }

  /// آخر موضوع تالٍ في نفس الباب (مطابق لمنطق البوت `next_topic`).
  static Future<Map<String, Object?>?> nextTopicInSubcategory(int topicId) async {
    final db = await instance;
    final cur = await db.rawQuery(
        'SELECT subcategory_id FROM topics WHERE id = ?', [topicId]);
    if (cur.isEmpty) return null;
    final sub = cur.first['subcategory_id'] as int;
    final rows = await db.rawQuery(
      'SELECT id, name FROM topics '
      'WHERE subcategory_id = ? AND id > ? AND is_active = 1 '
      'ORDER BY id LIMIT 1',
      [sub, topicId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  // ---- أسئلة ----------------------------------------------------------------

  static Future<List<Question>> questionsForTopic(int topicId) async {
    final db = await instance;
    final rows = await db.query('questions',
        where: 'topic_id = ?', whereArgs: [topicId], orderBy: 'question_order');
    return rows.map(Question.fromRow).toList();
  }

  /// أسئلة عشوائية. `categoryId = null` يوزّع التناسب بين كل التصنيفات
  /// (مطابق لمنطق `get_random_questions` في البوت).
  static Future<List<Question>> randomQuestions(
      int count, {int? categoryId}) async {
    final db = await instance;
    if (categoryId != null) {
      final rows = await db.rawQuery(
        'SELECT q.* FROM questions q '
        'JOIN topics t ON q.topic_id = t.id '
        'JOIN subcategories s ON t.subcategory_id = s.id '
        'WHERE s.category_id = ? AND q.options IS NOT NULL '
        'ORDER BY RANDOM() LIMIT ?',
        [categoryId, count],
      );
      return rows.map(Question.fromRow).toList();
    }

    final catRows = await db.rawQuery(
      'SELECT c.id, COUNT(q.id) AS qcount FROM categories c '
      'JOIN subcategories s ON s.category_id = c.id '
      'JOIN topics t ON t.subcategory_id = s.id '
      'JOIN questions q ON q.topic_id = t.id '
      'WHERE c.is_active = 1 AND s.is_active = 1 AND t.is_active = 1 '
      'AND q.options IS NOT NULL GROUP BY c.id HAVING qcount > 0 '
      'ORDER BY RANDOM()',
    );
    if (catRows.isEmpty) return [];

    final cats = catRows
        .map((r) => (id: r['id'] as int, count: r['qcount'] as int))
        .toList();
    final totalAvail = cats.fold<int>(0, (sum, c) => sum + c.count);
    final target = count < totalAvail ? count : totalAvail;
    final base = target ~/ cats.length;
    final remainder = target % cats.length;

    final out = <Question>[];
    final usedIds = <int>{};
    for (var i = 0; i < cats.length; i++) {
      var limit = base + (i < remainder ? 1 : 0);
      if (limit > cats[i].count) limit = cats[i].count;
      if (limit <= 0) continue;
      final rows = await db.rawQuery(
        'SELECT q.* FROM questions q '
        'JOIN topics t ON q.topic_id = t.id '
        'JOIN subcategories s ON t.subcategory_id = s.id '
        'WHERE s.category_id = ? AND q.options IS NOT NULL '
        'ORDER BY RANDOM() LIMIT ?',
        [cats[i].id, limit],
      );
      for (final r in rows) {
        out.add(Question.fromRow(r));
        usedIds.add(r['id'] as int);
      }
    }
    if (out.length < target) {
      final ph = List.filled(usedIds.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT * FROM questions WHERE options IS NOT NULL '
        'AND id NOT IN ($ph) ORDER BY RANDOM() LIMIT ?',
        [...usedIds, target - out.length],
      );
      out.addAll(rows.map(Question.fromRow));
    }
    return out;
  }
}