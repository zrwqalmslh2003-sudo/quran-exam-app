import 'dart:convert';

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
/// - جدول [remoteExams] يُخزّن محتوى الاختبارات البعيدة كما هو (JSON نصي)
///   بنسخة مُفعّلة ومُؤشّر نسخة فقط — لا يتمّ تطبيعها.
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
  /// عند [bootstrap] = false تُخطى التهيئة الأولية ويُنشأ المخطط فقط
  /// (مفيد في اختبارات Unit لا تملك ملفات أصول Flutter).
  static Future<SQLiteExamRepository> open({
    DatabaseFactory? factory,
    String? path,
    ExamRepository? fallback,
    bool bootstrap = true,
  }) async {
    final db = await (factory ?? databaseFactory).openDatabase(
      path ?? '${await getDatabasesPath()}/qalon_app.db',
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: (db, version) => _createSchema(db),
      ),
    );
    ExamRepository? effectiveFallback = fallback;
    if (effectiveFallback == null && bootstrap) {
      effectiveFallback = LocalExamRepository(await AppDataStore.instance);
    }
    final repo = SQLiteExamRepository._(db, effectiveFallback!);
    if (bootstrap) await repo._bootstrapIfEmpty();
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
    // جداول المحتوى البعيد — لا تُنشَأ من ملفات JSON، بل من GitHub.
    await db.execute('''
      CREATE TABLE remote_exams (
        exam_id    TEXT    NOT NULL,
        version    INTEGER NOT NULL,
        payload    TEXT    NOT NULL,
        is_active  INTEGER NOT NULL DEFAULT 0,
        activated_at TEXT,
        created_at TEXT    NOT NULL,
        UNIQUE(exam_id, version)
      )
    ''');
    await db.execute('''
      CREATE TABLE content_meta (
        key   TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
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
    final remote = await _tryActiveRemoteQuestions(count);
    if (remote != null) return remote;
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

  // ---- المحتوى البعيد (remote_exams + content_meta) -----------------------

  /// رقم نسخة المحتوى البعيدة المفعّلة حالياً لمعرّف [examId]، أو `null` إذا لا يوجد.
  Future<int?> remoteExamVersion(String examId) async {
    final rows = await _db.query(
      'remote_exams',
      columns: ['version'],
      where: 'exam_id = ? AND is_active = 1',
      whereArgs: [examId],
    );
    return rows.isNotEmpty ? rows.first['version'] as int : null;
  }

  /// يُخزّن JSON الاختبار كما هو مع تأشيرة [is_active] = 0.
  /// `ConflictAlgorithm.replace` يسمح بإعادة تخزين نفس الإصدار بأمان.
  Future<void> storeRemoteExam(
      String examId, int version, String payload) async {
    await _db.insert(
      'remote_exams',
      {
        'exam_id': examId,
        'version': version,
        'payload': payload,
        'is_active': 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// يُفعّل الإصدار [version] ويُوقف أي نسخة سابقة لنفس الاختبار
  /// في معاملة ذرّية واحدة.
  Future<void> activateRemoteExam(String examId, int version) async {
    await _db.transaction((txn) async {
      await txn.update(
        'remote_exams',
        {'is_active': 0},
        where: 'exam_id = ?',
        whereArgs: [examId],
      );
      await txn.update(
        'remote_exams',
        {
          'is_active': 1,
          'activated_at': DateTime.now().toIso8601String(),
        },
        where: 'exam_id = ? AND version = ?',
        whereArgs: [examId, version],
      );
    });
  }

  /// يعيد أسئلة الاختبار البعيد النشط (المخزّن محلياً في SQLite) حتى [count]،
  /// أو `null` عند غيابه أو فشل قراءته/تحليله — فيقع المتصل على المصدر المحلي.
  /// لا شبكة هنا أبداً: القراءة من قاعدة محلية فقط (Offline-first).
  Future<List<Question>?> _tryActiveRemoteQuestions(int count) async {
    try {
      final rows = await _db.query(
        'remote_exams',
        columns: ['payload'],
        where: 'is_active = 1',
        orderBy: 'activated_at DESC',
      );
      if (rows.isEmpty) return null;
      final payload = rows.first['payload'];
      if (payload is! String || payload.isEmpty) return null;
      final questions = _parseRemoteQuestions(payload);
      return questions.take(count).toList();
    } catch (_) {
      return null;
    }
  }

  /// يحلل حمولة اختبار بعيد (عقد schemaVersion 1) إلى أسئلة المحرك.
  /// الحمولة المخزّنة لا تُعدّل ولا تُحذف مهما كان الفشل.
  List<Question> _parseRemoteQuestions(String rawPayload) {
    final decoded = jsonDecode(rawPayload);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('حمولة الاختبار البعيد يجب أن تكون كائناً JSON');
    }
    final questions = decoded['questions'];
    if (questions is! List || questions.isEmpty) {
      throw const FormatException('حمولة الاختبار البعيد بلا أسئلة');
    }
    final out = <Question>[];
    for (var i = 0; i < questions.length; i++) {
      final item = questions[i];
      if (item is! Map) {
        throw const FormatException('سؤال بعيد تالف');
      }
      out.add(Question.fromRemote(item.cast<String, Object?>(), i));
    }
    return out;
  }

  Future<String?> manifestMetaValue(String key) async {
    final rows = await _db.query(
      'content_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isNotEmpty ? rows.first['value'] as String : null;
  }

  Future<void> setManifestMeta(String key, String value) async {
    await _db.insert(
      'content_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}