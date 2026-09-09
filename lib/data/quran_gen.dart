import 'dart:math';

import 'app_data.dart';

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
  final AppDataStore store;

  QuranGenerator(this.store);

  Quarter? _quarter(int? quarterId) {
    if (quarterId == null) return null;
    for (final q in quarters) {
      if (q.id == quarterId) return q;
    }
    return null;
  }

  /// Returns a random ayah, optionally limited to a quarter and excluding ids.
  Future<Ayah?> randomAyah({Set<int>? excludeIds, int? quarterId}) async {
    final q = _quarter(quarterId);
    final candidates = <Map<String, Object?>>[];
    for (final v in store.table('verses')) {
      if (q != null) {
        final g = v['group_id'];
        if (g is! int || g < q.hizbStart || g > q.hizbEnd) continue;
      }
      if (excludeIds != null && excludeIds.contains(v['id'])) continue;
      candidates.add(v);
    }
    if (candidates.isEmpty) return null;

    final r = candidates[Random().nextInt(candidates.length)];
    final chapterId = r['chapter_id'] as int;
    final surahName = _surahName(chapterId);
    final tafseer = _tafseer(chapterId, r['number'] as int);
    return Ayah(
      r['id'] as int,
      chapterId,
      surahName,
      r['number'] as int,
      r['content'] as String,
      tafseer,
    );
  }

  /// Returns up to [limit] random surahs for distractors, optionally within
  /// the same quarter as the answer. Returns empty if a quarter can't fill.
  Future<List<SurahPick>> randomSurahs(
      int excludeId, int limit, int? quarterId) async {
    final q = _quarter(quarterId);
    if (quarterId != null && q == null) return [];

    final chapters = store.table('chapters');
    final rand = Random();
    if (q != null) {
      final inRange = <int>{};
      for (final v in store.table('verses')) {
        final g = v['group_id'];
        if (g is int && g >= q.hizbStart && g <= q.hizbEnd) {
          final c = v['chapter_id'];
          if (c is int) inRange.add(c);
        }
      }
      final pool = chapters
          .where((c) =>
              c['id'] is int &&
              c['id'] != excludeId &&
              inRange.contains(c['id']))
          .toList()
        ..shuffle(rand);
      return pool
          .take(limit)
          .map((r) => SurahPick(r['id'] as int, r['name'] as String))
          .toList();
    }

    final pool = chapters.where((c) => c['id'] != excludeId).toList()
      ..shuffle(rand);
    return pool
        .take(limit)
        .map((r) => SurahPick(r['id'] as int, r['name'] as String))
        .toList();
  }

  String _surahName(int chapterId) {
    for (final c in store.table('chapters')) {
      if (c['id'] == chapterId) return c['name'] as String? ?? '';
    }
    return '';
  }

  String? _tafseer(int chapterId, int verseNumber) {
    for (final t in store.table('tafseer')) {
      if (t['chapter_id'] == chapterId && t['verse_num'] == verseNumber) {
        final txt = t['text'];
        if (txt is String) return txt.trim();
        return null;
      }
    }
    return null;
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

/// سؤال مولّد من آية — يمثّل عناصر سؤال واحد في اختبار الآيات.
class AyahQuestion {
  final Ayah ayah;
  final List<SurahPick> options;

  const AyahQuestion(this.ayah, this.options);

  /// فهرس الإجابة الصحيحة (سورة الآية) داخل الخيارات.
  int get correctIndex {
    for (var i = 0; i < options.length; i++) {
      if (options[i].id == ayah.chapterId) return i;
    }
    return -1;
  }
}

/// يبني قائمة جاهزة من أسئلة الآيات حتى الحد المطلوب،
/// مع استبعاد الآيات المستخدمة وعدم تكرارها.
Future<List<AyahQuestion>> buildAyahExam(QuranGenerator gen, int quarterId,
    {required int limit}) async {
  final excluded = <int>{};
  final out = <AyahQuestion>[];
  for (var i = 0; i < limit; i++) {
    final q = await buildAyahQuestion(gen, quarterId, excludeAyahIds: excluded);
    if (q == null) break;
    excluded.add(q.ayah.id);
    out.add(AyahQuestion(q.ayah, q.options));
  }
  return out;
}