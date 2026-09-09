import 'package:sqflite/sqflite.dart';

import '../models/question.dart';
import 'app_data.dart';
import 'exam_repository.dart';
import 'quran_gen.dart';
import 'question_picker.dart';
import 'table_source.dart';

/// SQLite هو المصدر الأساسي بعد التهيئة.
///
/// - التهيئة الأولى (Bootstrap): تُنسخ بيانات JSON المضمّنة إلى SQLite مرة واحدة.
/// - بعد ذلك يُقرأ التطبيق من SQLite فقط ولا يُعاد الاستيراد أبداً،
///   حتى لو تغيّر JSON المضمّن في نسخة أحدث من التطبيق.
/// - عند فشل الفتح أو القراءة ([_fallback]) تُستخدم نسخة JSON كاحتياط.
class SQLiteExamRepository implements ExamRepository, TableSource {
  static const _dbVersion = 1;

  /// الجداول المنعكسة عن ملفات JSON المضمّنة (نفس الأعمدة تماماً).
  static const tablesToCopy = [
    'categories',
    'subcategories',
    'topics',
    'questions',
    'chapters',
    'verses',
    'tafseer',
  ];

  final Database _db;
  final ExamRepository _fallback;
  final Map<String, List<Map<String, Object?>>> _cache = {};

  SQLiteExamRepository._(this._db, this._fallback);

  /// يفتح قاعدة (ينشئ الجدولا عند أول تشغيل) ويدير التهيئة الأولية.
  ///
  /// [factory]/[path] يُمرّران في الاختبارات (FFI وملف مؤقّت)؛
  /// في التطبيق يُستخدم افتراضياً مصنع sqflite القياسي (MethodChannel).
  static Future<SQLiteExamRepository> open({
    DatabaseFactory? factory,
    String? path,
    ExamRepository? fallback,
  }) async {
    final db = await (factory ?? databaseFactory).openDatabase(
      path ?? '${await getDatabasesPath()}/qalon_app.db',
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: (db, version) => _createSchema(db),
      ),
    );
    final repo = SQLiteExamRepository._(
        db, fallback ?? LocalExamRepository(await AppDataStore.instance));
    await repo._bootstrapIfEmpty();
    await repo._loadCache();
    return repo;
  }

  static Future<void> _createSchema(Database db) async {
    final definitions = <String, Map<String, String>>{
      'categories': {
        'id': 'INTEGER PRIMARY KEY',
        'name': 'TEXT',
        'emoji': 'TEXT',
        'sort_order': 'INTEGER',
        'is_active': 'INTEGER',
      },
      'subcategories': {
        'id': 'INTEGER PRIMARY KEY',
        'category_id': 'INTEGER',
        'name': 'TEXT',
        'emoji': 'TEXT',
        'sort_order': 'INTEGER',
        'is_active': 'INTEGER',
      },
      'topics': {
        'id': 'INTEGER PRIMARY KEY',
        'name': 'TEXT',
        'description': 'TEXT',
        'is_active': 'INTEGER',
        'subcategory_id': 'INTEGER',
      },
      'questions': {
        'id': 'INTEGER PRIMARY KEY',
        'topic_id': 'INTEGER',
        'question_order': 'INTEGER',
        'text': 'TEXT',
        'type': 'TEXT',
        'options': 'TEXT',
        'correct_option_id': 'INTEGER',
        'explanation': 'TEXT',
        'expected': 'TEXT',
        'created_at': 'TEXT',
        'correct_option_ids': 'TEXT',
        'allows_multiple_answers': 'INTEGER',
        'points': 'INTEGER',
      },
      'chapters': {
        'id': 'INTEGER PRIMARY KEY',
        'name': 'TEXT',
      },
      'verses': {
        'id': 'INTEGER PRIMARY KEY',
        'chapter_id': 'INTEGER',
        'number': 'INTEGER',
        'content': 'TEXT',
        'group_id': 'INTEGER',
      },
      'tafseer': {
        'chapter_id': 'INTEGER',
        'verse_num': 'INTEGER',
        'text': 'TEXT',
      },
    };

    await db.execute('PRAGMA foreign_keys = ON');
    for (final entry in definitions.entries) {
      final cols = entry.value.entries
          .map((c) => '${c.key} ${c.value}')
          .join(', ');
      await db.execute('CREATE TABLE ${entry.key} ($cols)');
    }
  }

  /// يُنسخ JSON المضمّن إلى SQLite فقط إذا كانت قاعدة الأسئلة فارغة.
  /// لا يُكتب فوق قاعدة موجودة أبداً.
  Future<void> _bootstrapIfEmpty() async {
    if (await _count('questions') > 0) return;

    final store = await AppDataStore.instance;
    await _db.transaction((txn) async {
      for (final name in tablesToCopy) {
        final rows = store.table(name);
        if (rows.isEmpty) continue;
        final cols = rows.first.keys.toList();
        final batch = txn.batch();
        for (final row in rows) {
          batch.insert(
            name,
            {for (final c in cols) c: row[c]},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<void> _loadCache() async {
    for (final name in tablesToCopy) {
      final rows = await _db.query(name);
      _cache[name] = rows
          .map((r) => r.map<String, Object?>((k, v) => MapEntry(k, v)))
          .toList();
    }
  }

  Future<int> _count(String table) async {
    final rows = await _db.rawQuery('SELECT COUNT(*) c FROM $table');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> close() => _db.close();

  @override
  List<Map<String, Object?>> table(String name) => _cache[name] ?? [];

  @override
  Future<List<Question>> questionsForTopic(int topicId) async {
    try {
      final rows = await _db.query(
        'questions',
        where: 'topic_id = ?',
        whereArgs: [topicId],
        orderBy: 'question_order ASC',
      );
      return rows.map(Question.fromRow).toList();
    } catch (_) {
      return _fallback.questionsForTopic(topicId);
    }
  }

  @override
  Future<List<Question>> randomQuestions(int count, {int? categoryId}) async {
    try {
      return QuestionPicker.pick(
        categories: _cache['categories'] ?? const [],
        subcategories: _cache['subcategories'] ?? const [],
        topics: _cache['topics'] ?? const [],
        questions: _cache['questions'] ?? const [],
        count: count,
        categoryId: categoryId,
      );
    } catch (_) {
      return _fallback.randomQuestions(count, categoryId: categoryId);
    }
  }

  @override
  Future<List<AyahQuestion>> ayahExam(int quarterId,
      {required int limit}) async {
    try {
      return buildAyahExam(QuranGenerator(this), quarterId, limit: limit);
    } catch (_) {
      return _fallback.ayahExam(quarterId, limit: limit);
    }
  }
}