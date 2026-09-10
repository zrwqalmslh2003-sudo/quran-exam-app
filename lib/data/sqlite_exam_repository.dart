import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/question.dart';
import 'app_data.dart';
import 'exam_catalog.dart';
import 'exam_repository.dart';
import 'quran_gen.dart';
import 'question_picker.dart';
import 'table_source.dart';

class RemoteExamPayload {
  const RemoteExamPayload({
    required this.examId,
    required this.version,
    required this.payload,
    this.categoryId,
    this.subcategoryId,
    this.newCategoryName,
    this.newSubcategoryName,
  });

  final String examId;
  final int version;
  final String payload;

  /// مرجع category محلية (عدد صحيح) أو name لإنشاء category بعيدة.
  final int? categoryId;
  final int? subcategoryId;
  final String? newCategoryName;
  final String? newSubcategoryName;
}

/// علاقة exam → شجرة بعيدة (category/subcategory) لاختبار نشط.
class RemoteHierarchyRow {
  const RemoteHierarchyRow({
    required this.examId,
    this.categoryReference,
    this.subcategoryReference,
  });

  final String examId;
  final String? categoryReference;
  final String? subcategoryReference;
}

/// فرع بعيد (category) جاهز للملاحة: يحمل subcategories والأختبارات المباشرة.
class RemoteCategoryNode {
  const RemoteCategoryNode({
    required this.reference,
    required this.name,
    this.emoji,
    this.subcategories = const [],
    this.examIds = const [],
  });

  final String reference;
  final String name;
  final String? emoji;
  final List<RemoteSubcategoryNode> subcategories;
  final List<String> examIds;
}

/// subcategory بعيد تحت [RemoteCategoryNode.categoryReference].
class RemoteSubcategoryNode {
  const RemoteSubcategoryNode({
    required this.reference,
    required this.name,
    this.emoji,
    this.examIds = const [],
  });

  final String reference;
  final String name;
  final String? emoji;
  final List<String> examIds;
}

/// صف كاتبة في جداول hierarchy البعيدة أثناء التحديث.
class _CategoryWrite {
  const _CategoryWrite(this.reference, this.name);

  final String reference;
  final String name;
}

class _SubcategoryWrite {
  const _SubcategoryWrite(
      this.reference, this.categoryReference, this.name);

  final String reference;
  final String categoryReference;
  final String name;
}

/// SQLite هو المصدر الأساسي بعد التهيئة.
///
/// - التهيئة الأولى (Bootstrap): تُنسخ بيانات JSON المضمّنة إلى SQLite مرة واحدة.
/// - بعد ذلك يُقرأ التطبيق من SQLite فقط ولا يُعاد الاستيراد أبداً،
///   حتى لو تغيّر JSON المضمّن في نسخة أحدث من التطبيق.
/// - عند فشل الفتح أو القراءة ([_fallback]) تُستخدم نسخة JSON كاحتياط.
/// - جدول [remoteExams] يُخزّن محتوى الاختبارات البعيدة كما هو (JSON نصي)
///   بنسخة مُفعّلة ومُؤشّر نسخة فقط — لا يتمّ تطبيعها.
class SQLiteExamRepository implements ExamRepository, ExamCatalogRepository, TableSource {
  static const _dbVersion = 2;

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
        onUpgrade: (db, oldVersion, newVersion) =>
            _upgradeSchema(db, oldVersion, newVersion),
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
    await _createRemoteHierarchyTables(db);
  }

  /// ترقية المخطط من نسخة قديمة دون إتلاف المحتوى المثبّت.
  static Future<void> _upgradeSchema(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createRemoteHierarchyTables(db);
    }
  }

  /// جداول الشجرة البعيدة (remote_categories/remote_subcategories/
  /// remote_exam_hierarchy) — تُنشأ من GitHub لا من JSON المضمّن.
  /// `IF NOT EXISTS` يجعل الاستدعاء آمناً من onCreate ومن onUpgrade.
  static Future<void> _createRemoteHierarchyTables(
      DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS remote_categories (
        reference TEXT PRIMARY KEY,
        name      TEXT NOT NULL,
        emoji     TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS remote_subcategories (
        reference          TEXT PRIMARY KEY,
        category_reference TEXT NOT NULL,
        name               TEXT NOT NULL,
        emoji              TEXT,
        sort_order         INTEGER NOT NULL DEFAULT 0,
        is_active          INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS remote_exam_hierarchy (
        exam_id              TEXT PRIMARY KEY,
        category_reference   TEXT,
        subcategory_reference TEXT
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
    final remote = await _tryActiveRemoteQuestions(count, categoryId: categoryId);
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

  @override
  Future<List<ExamCatalogEntry>> activeExamCatalog() async {
    try {
      final rows = await _db.query(
        'remote_exams',
        columns: ['payload'],
        where: 'is_active = 1',
        orderBy: 'activated_at ASC, exam_id ASC',
      );
      final entries = <ExamCatalogEntry>[];
      for (final row in rows) {
        final payload = row['payload'];
        if (payload is! String || payload.isEmpty) continue;
        try {
          entries.add(ExamCatalogEntry.fromPayload(payload));
        } catch (_) {
          // محتوى بعيد تالف لا يُسقط بقية الكتالوج.
        }
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }

  /// علاقات (exam → category/subcategory) للاختبارات النشطة فقط.
  Future<List<RemoteHierarchyRow>> remoteHierarchyRows() async {
    try {
      final active = await _db.query(
        'remote_exams',
        columns: ['exam_id'],
        where: 'is_active = 1',
      );
      if (active.isEmpty) return const [];
      final activeIds =
          active.map((r) => r['exam_id'] as String).toSet();
      final rows = await _db.query('remote_exam_hierarchy');
      final out = <RemoteHierarchyRow>[];
      for (final row in rows) {
        final examId = row['exam_id'];
        if (examId is! String || !activeIds.contains(examId)) continue;
        out.add(RemoteHierarchyRow(
          examId: examId,
          categoryReference: row['category_reference'] as String?,
          subcategoryReference: row['subcategory_reference'] as String?,
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// شجرة التصنيفات البعيدة (category → subcategories → exams) للاختبارات
  /// النشطة، بأسماء محلولة من المحلية عند مرجع `local:*`.
  Future<List<RemoteCategoryNode>> remoteCategoryTree() async {
    try {
      final active = await _db.query(
        'remote_exams',
        columns: ['exam_id'],
        where: 'is_active = 1',
      );
      if (active.isEmpty) return const [];
      final activeIds =
          active.map((r) => r['exam_id'] as String).toSet();

      final categoryRows =
          await _db.query('remote_categories', where: 'is_active = 1');
      final subcategoryRows =
          await _db.query('remote_subcategories', where: 'is_active = 1');
      final hierarchyRows = await _db.query('remote_exam_hierarchy');

      final localCats = _cache['categories'] ?? const [];
      final localSubs = _cache['subcategories'] ?? const [];
      final subExams = <String, List<String>>{};
      final categoryDirect = <String, List<String>>{};
      for (final row in hierarchyRows) {
        final examId = row['exam_id'];
        if (examId is! String || !activeIds.contains(examId)) continue;
        final catRef = row['category_reference'] as String?;
        final subRef = row['subcategory_reference'] as String?;
        if (catRef == null) continue;
        if (subRef != null) {
          subExams.putIfAbsent(subRef, () => []).add(examId);
        } else {
          categoryDirect.putIfAbsent(catRef, () => []).add(examId);
        }
      }

      final nodes = <RemoteCategoryNode>[];
      for (final row in categoryRows) {
        final ref = row['reference'] as String?;
        final name = row['name'] as String?;
        if (ref == null || name == null) continue;
        final isActive = row['is_active'] == 1;
        if (!isActive) continue;
        nodes.add(RemoteCategoryNode(
          reference: ref,
          name: name,
          emoji: row['emoji'] as String?,
        ));
      }
      for (final row in subcategoryRows) {
        final ref = row['reference'] as String?;
        final parent = row['category_reference'] as String?;
        final name = row['name'] as String?;
        if (ref == null || parent == null || name == null) continue;
        final isActive = row['is_active'] == 1;
        if (!isActive) continue;
        final parentIdx = nodes.indexWhere((n) => n.reference == parent);
        if (parentIdx < 0) continue;
        final subs = List<RemoteSubcategoryNode>.of(nodes[parentIdx].subcategories);
        subs.add(RemoteSubcategoryNode(
          reference: ref,
          name: name,
          emoji: row['emoji'] as String?,
        ));
        nodes[parentIdx] = RemoteCategoryNode(
          reference: nodes[parentIdx].reference,
          name: nodes[parentIdx].name,
          emoji: nodes[parentIdx].emoji,
          subcategories: subs,
          examIds: nodes[parentIdx].examIds,
        );
      }

      final out = <RemoteCategoryNode>[];
      for (final node in nodes) {
        final resolvedName = _resolveLocalName(
          node.reference,
          localCats,
          localSubs,
          fallbackName: node.name,
        );
        final resolvedEmoji = _resolveLocalEmoji(node.reference, localCats, localSubs)
            ?? node.emoji;
        final subs = node.subcategories.map((s) {
          final subName = _resolveLocalName(
            s.reference,
            localCats,
            localSubs,
            fallbackName: s.name,
          );
          final subEmoji = _resolveLocalEmoji(s.reference, localCats, localSubs)
              ?? s.emoji;
          return RemoteSubcategoryNode(
            reference: s.reference,
            name: subName,
            emoji: subEmoji,
            examIds: List.unmodifiable(subExams[s.reference] ?? const []),
          );
        }).toList()
          ..sort(_compareNamedSub);
        final exams = categoryDirect[node.reference] ?? const <String>[];
        out.add(RemoteCategoryNode(
          reference: node.reference,
          name: resolvedName,
          emoji: resolvedEmoji,
          subcategories: subs,
          examIds: List.unmodifiable(exams),
        ));
      }
      out.sort(_compareNamed);
      return out;
    } catch (_) {
      return const [];
    }
  }

  static int _compareNamed(RemoteCategoryNode a, RemoteCategoryNode b) {
    final byOrder = a.name.compareTo(b.name);
    return byOrder != 0 ? byOrder : a.reference.compareTo(b.reference);
  }

  static int _compareNamedSub(RemoteSubcategoryNode a, RemoteSubcategoryNode b) {
    final byOrder = a.name.compareTo(b.name);
    return byOrder != 0 ? byOrder : a.reference.compareTo(b.reference);
  }

  static String? _resolveLocalName(
    String ref,
    List<Map<String, Object?>> localCats,
    List<Map<String, Object?>> localSubs, {
    required String fallbackName,
  }) {
    final localName = ref.startsWith('local:c:')
        ? _localField(localCats, ref.substring('local:c:'.length), 'name')
        : (ref.startsWith('local:sc:')
            ? _localField(localSubs, ref.substring('local:sc:'.length), 'name')
            : null);
    return localName is String && localName.isNotEmpty ? localName : fallbackName;
  }

  static String? _resolveLocalEmoji(
    String ref,
    List<Map<String, Object?>> localCats,
    List<Map<String, Object?>> localSubs,
  ) {
    final emoji = ref.startsWith('local:c:')
        ? _localField(localCats, ref.substring('local:c:'.length), 'emoji')
        : (ref.startsWith('local:sc:')
            ? _localField(localSubs, ref.substring('local:sc:'.length), 'emoji')
            : null);
    return emoji is String ? emoji : null;
  }

  static Object? _localField(
    List<Map<String, Object?>> rows,
    String idString,
    String column,
  ) {
    final id = int.tryParse(idString);
    if (id == null) return null;
    for (final row in rows) {
      if (row['id'] == id) return row[column];
    }
    return null;
  }

  @override
  Future<List<Question>> questionsForExam(String examId) async {
    try {
      final rows = await _db.query(
        'remote_exams',
        columns: ['payload'],
        where: 'exam_id = ? AND is_active = 1',
        whereArgs: [examId],
        orderBy: 'activated_at DESC',
        limit: 1,
      );
      if (rows.isEmpty || rows.first['payload'] is! String) return const [];
      return _parseRemoteQuestions(rows.first['payload'] as String);
    } catch (_) {
      return const [];
    }
  }
  /// `ConflictAlgorithm.replace` يسمح بإعادة تخزين نفس الإصدار بأمان.
  /// يُنشأ/يُستبدل سطر hierarchy (بمراجع فارغة) حتى لا يوجد exam نشط بلا mapping.
  Future<void> storeRemoteExam(
      String examId, int version, String payload) async {
    await _db.transaction((txn) async {
      await txn.insert(
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
      await txn.insert(
        'remote_exam_hierarchy',
        {'exam_id': examId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
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

  /// Stores and activates a complete, already validated manifest update in one
  /// transaction. Existing active content remains active if any write fails.
  ///
  /// To each staged exam it writes, in the SAME transaction:
  /// - the exam payload (as today),
  /// - a category mapping (`remote_categories`),
  /// - a subcategory mapping (`remote_subcategories`),
  /// - the exam → hierarchy reference (`remote_exam_hierarchy`).
  ///
  /// Identity rules (deterministic):
  /// - a local category by id resolves to `local:c:<id>`;
  /// - a new category name resolves to `remote:c:<slug(name)>`;
  /// - a new name matching an existing local category name resolves to the
  ///   local one (no duplicate);
  /// - repeated new names inside one manifest produce the same reference;
  /// - a new subcategory owns a deterministic parent category reference.
  Future<void> applyRemoteUpdate({
    required List<RemoteExamPayload> exams,
    required int contentVersion,
  }) async {
    final localCategories = await _db.query(
      'categories',
      where: 'is_active = 1',
    );
    final localSubcategories = await _db.query(
      'subcategories',
      where: 'is_active = 1',
    );

    final categoryWrites = <String, _CategoryWrite>{};
    final subcategoryWrites = <String, _SubcategoryWrite>{};
    final hierarchyRows = <({String examId, String? category, String? sub})>[];
    for (final exam in exams) {
      final resolved = _resolveHierarchy(
        exam,
        localCategories,
        localSubcategories,
      );
      final catWrite = resolved.categoryWrite;
      final subWrite = resolved.subcategoryWrite;
      if (catWrite != null) categoryWrites[catWrite.reference] = catWrite;
      if (subWrite != null) {
        subcategoryWrites[subWrite.reference] = subWrite;
      }
      hierarchyRows.add(
        (examId: exam.examId, category: resolved.category, sub: resolved.sub),
      );
    }

    await _db.transaction((txn) async {
      for (final exam in exams) {
        await txn.insert(
          'remote_exams',
          {
            'exam_id': exam.examId,
            'version': exam.version,
            'payload': exam.payload,
            'is_active': 0,
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final exam in exams) {
        await txn.update(
          'remote_exams',
          {'is_active': 0},
          where: 'exam_id = ?',
          whereArgs: [exam.examId],
        );
        await txn.update(
          'remote_exams',
          {
            'is_active': 1,
            'activated_at': DateTime.now().toIso8601String(),
          },
          where: 'exam_id = ? AND version = ?',
          whereArgs: [exam.examId, exam.version],
        );
      }

      for (final write in categoryWrites.values) {
        await txn.insert(
          'remote_categories',
          {
            'reference': write.reference,
            'name': write.name,
            'sort_order': 0,
            'is_active': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final write in subcategoryWrites.values) {
        await txn.insert(
          'remote_subcategories',
          {
            'reference': write.reference,
            'category_reference': write.categoryReference,
            'name': write.name,
            'sort_order': 0,
            'is_active': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final row in hierarchyRows) {
        await txn.insert(
          'remote_exam_hierarchy',
          {
            'exam_id': row.examId,
            'category_reference': row.category,
            'subcategory_reference': row.sub,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.insert(
        'content_meta',
        {
          'key': 'manifest_content_version',
          'value': contentVersion.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// يحوّل مراجع hierarchy في [exam] إلى references حتمية.
  /// يُرجع `(category, subcategory, categoryWrite?, subcategoryWrite?)`
  /// حيث `calWrite`/`subWrite` غير فارغين فقط عند إنشاء remote فعلي.
  ({
    String? category,
    String? sub,
    _CategoryWrite? categoryWrite,
    _SubcategoryWrite? subcategoryWrite
  }) _resolveHierarchy(
    RemoteExamPayload exam,
    List<Map<String, Object?>> localCategories,
    List<Map<String, Object?>> localSubcategories,
  ) {
    String? categoryRef;
    _CategoryWrite? categoryWrite;

    final newCategoryName = exam.newCategoryName;
    if (newCategoryName != null) {
      final slugName = _slug(newCategoryName);
      final localHit = _firstActiveNamed(
        localCategories,
        slugName,
      );
      if (localHit != null) {
        categoryRef = 'local:c:${localHit['id']}';
      } else {
        categoryRef = 'remote:c:$slugName';
        categoryWrite = _CategoryWrite(categoryRef, newCategoryName.trim());
      }
    } else if (exam.categoryId != null) {
      categoryRef = 'local:c:${exam.categoryId}';
    } else if (exam.subcategoryId != null) {
      // بدون categoryId — نشتق الـ parent من ansubcategory المحلية.
      final parentId = _parentCategoryOf(localSubcategories, exam.subcategoryId!);
      if (parentId != null) categoryRef = 'local:c:$parentId';
    }

    String? subRef;
    _SubcategoryWrite? subcategoryWrite;

    final newSubcategoryName = exam.newSubcategoryName;
    if (newSubcategoryName != null) {
      final slugName = _slug(newSubcategoryName);
      final parentRef = categoryRef;
      if (parentRef != null && parentRef.startsWith('local:c:')) {
        final localParentId =
            int.tryParse(parentRef.substring('local:c:'.length));
        final localHit = _firstSubcategoryMatching(
          localSubcategories,
          localParentId: localParentId,
          slugName: slugName,
        );
        if (localHit != null) {
          subRef = 'local:sc:${localHit['id']}';
        } else {
          subRef = 'remote:sc:$parentRef:$slugName';
          subcategoryWrite = _SubcategoryWrite(
            subRef,
            parentRef,
            newSubcategoryName.trim(),
          );
        }
      } else if (parentRef != null) {
        subRef = 'remote:sc:$parentRef:$slugName';
        subcategoryWrite = _SubcategoryWrite(
          subRef,
          parentRef,
          newSubcategoryName.trim(),
        );
      } else if (exam.subcategoryId != null) {
        // بلا parent واضح — الأب هو category من subcategory محلية موجودة.
        final parentId =
            _parentCategoryOf(localSubcategories, exam.subcategoryId!);
        if (parentId != null) {
          final parentSubRef = 'local:c:$parentId';
          subRef = 'remote:sc:$parentSubRef:$slugName';
          subcategoryWrite = _SubcategoryWrite(
            subRef,
            parentSubRef,
            newSubcategoryName.trim(),
          );
        }
      }
    } else if (exam.subcategoryId != null) {
      subRef = 'local:sc:${exam.subcategoryId}';
    }

    return (
      category: categoryRef,
      sub: subRef,
      categoryWrite: categoryWrite,
      subcategoryWrite: subcategoryWrite,
    );
  }

  static String _slug(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), '_');

  static Map<String, Object?>? _firstActiveNamed(
    List<Map<String, Object?>> rows,
    String slugName,
  ) {
    for (final row in rows) {
      if (row['is_active'] == 1 && _slug(row['name'] as String) == slugName) {
        return row;
      }
    }
    return null;
  }

  static int? _parentCategoryOf(
    List<Map<String, Object?>> subcategories,
    int subcategoryId,
  ) {
    for (final row in subcategories) {
      if (row['id'] == subcategoryId) {
        final parent = row['category_id'];
        return parent is int ? parent : null;
      }
    }
    return null;
  }

  static Map<String, Object?>? _firstSubcategoryMatching(
    List<Map<String, Object?>> rows, {
    required int? localParentId,
    required String slugName,
  }) {
    for (final row in rows) {
      if (row['is_active'] == 1 &&
          row['category_id'] == localParentId &&
          _slug(row['name'] as String) == slugName) {
        return row;
      }
    }
    return null;
  }

  /// يعيد أسئلة الاختبار البعيد النشط (المخزّن محلياً في SQLite) حتى [count]،
  /// أو `null` عند غيابه أو فشل قراءته/تحليله — فيقع المتصل على المصدر المحلي.
  /// لا شبكة هنا أبداً: القراءة من قاعدة محلية فقط (Offline-first).
  Future<List<Question>?> _tryActiveRemoteQuestions(
    int count, {
    int? categoryId,
  }) async {
    // quran_general is the only remote random exam until v1.6 introduces
    // explicit catalog/exam selection. A category-scoped request must use the
    // local picker because this payload has no category contract yet.
    if (categoryId != null) return null;
    try {
      final rows = await _db.query(
        'remote_exams',
        columns: ['payload'],
        where: 'exam_id = ? AND is_active = 1',
        whereArgs: ['quran_general'],
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
