import 'package:sqflite/sqflite.dart';

class Quarter {
  final int id;
  final String name;
  final String emoji;
  final int hizbStart;
  final int hizbEnd;

  const Quarter(this.id, this.name, this.emoji, this.hizbStart, this.hizbEnd);
}

const List<Quarter> quarters = [
  Quarter(1, 'ربع البقرة', '🐂', 1, 15),
  Quarter(2, 'ربع الأعراف', '🕌', 16, 30),
  Quarter(3, 'ربع الكهف', '🕋', 31, 45),
  Quarter(4, 'ربع يس', '🌟', 46, 60),
];

class Ayah {
  final int id;
  final int chapterId;
  final String surahName;
  final int verseNumber;
  final String text;
  final String? tafseer;

  const Ayah(this.id, this.chapterId, this.surahName, this.verseNumber,
      this.text, this.tafseer);
}

class SurahPick {
  final int id;
  final String name;
  const SurahPick(this.id, this.name);
}

class QuranGenerator {
  final Database db;

  QuranGenerator(this.db);

  /// Returns a random ayah, optionally limited to a quarter and excluding ids.
  Future<Ayah?> randomAyah({Set<int>? excludeIds, int? quarterId}) async {
    final clauses = <String>[];
    final args = <Object?>[];

    if (quarterId != null) {
      final q = quarters.firstWhere((e) => e.id == quarterId,
          orElse: () => const Quarter(0, '', '', 0, 0));
      if (q.id != 0) {
        clauses.add('v.group_id BETWEEN ? AND ?');
        args.addAll([q.hizbStart, q.hizbEnd]);
      }
    }

    if (excludeIds != null && excludeIds.isNotEmpty) {
      clauses.add('v.id NOT IN (${List.filled(excludeIds.length, '?').join(',')})');
      args.addAll(excludeIds);
    }

    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final rows = await db.rawQuery(
      'SELECT v.id, v.chapter_id, c.name AS surah_name, v.number, v.content '
      'FROM verses v JOIN chapters c ON v.chapter_id = c.id '
      '$where ORDER BY RANDOM() LIMIT 1',
      args,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    final tafseer = await _tafseer(r['chapter_id'] as int, r['number'] as int);
    return Ayah(
      r['id'] as int,
      r['chapter_id'] as int,
      r['surah_name'] as String,
      r['number'] as int,
      r['content'] as String,
      tafseer,
    );
  }

  /// Returns up to [limit] random surahs for distractors, optionally within
  /// the same quarter as the answer. Returns empty if a quarter can't fill.
  Future<List<SurahPick>> randomSurahs(
      int excludeId, int limit, int? quarterId) async {
    if (quarterId != null) {
      final q = quarters.firstWhere((e) => e.id == quarterId,
          orElse: () => const Quarter(0, '', '', 0, 0));
      if (q.id == 0) return [];
      final rows = await db.rawQuery(
        'SELECT DISTINCT c.id, c.name FROM chapters c '
        'JOIN verses v ON v.chapter_id = c.id '
        'WHERE v.group_id BETWEEN ? AND ? AND c.id != ? '
        'ORDER BY RANDOM() LIMIT ?',
        [q.hizbStart, q.hizbEnd, excludeId, limit],
      );
      return rows.map((r) => SurahPick(r['id'] as int, r['name'] as String)).toList();
    }
    final rows = await db.rawQuery(
      'SELECT id, name FROM chapters WHERE id != ? ORDER BY RANDOM() LIMIT ?',
      [excludeId, limit],
    );
    return rows.map((r) => SurahPick(r['id'] as int, r['name'] as String)).toList();
  }

  Future<String?> _tafseer(int chapterId, int verseNumber) async {
    final rows = await db.query('tafseer',
        where: 'chapter_id = ? AND verse_num = ?',
        whereArgs: [chapterId, verseNumber],
        limit: 1);
    if (rows.isEmpty) return null;
    return (rows.first['text'] as String).trim();
  }
}

/// Builds the "ayah → which surah?" question options for a quarter.
Future<({Ayah ayah, List<SurahPick> options})?> buildAyahQuestion(
    QuranGenerator gen, int quarterId, {Set<int>? excludeAyahIds}) async {
  final ayah = await gen.randomAyah(excludeIds: excludeAyahIds, quarterId: quarterId);
  if (ayah == null) return null;
  final distractors = await gen.randomSurahs(ayah.chapterId, 3, quarterId);
  if (distractors.length < 3) return null;
  final answer = SurahPick(ayah.chapterId, ayah.surahName);
  final options = ([answer, ...distractors]..shuffle());
  return (ayah: ayah, options: options);
}
