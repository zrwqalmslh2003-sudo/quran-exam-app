import 'dart:convert';

enum QuestionType {
  poll,
  quiz,
  trueFalse,
  other;

  static QuestionType from(String s) => switch (s) {
        'poll' => QuestionType.poll,
        'quiz' => QuestionType.quiz,
        'single_choice' => QuestionType.quiz,
        'true_false' => QuestionType.trueFalse,
        _ => QuestionType.other,
      };
}

/// سؤال من جدول `questions` في قاعدة البوت.
class Question {
  final int id;
  final int topicId;
  final int order;
  final String text;
  final QuestionType type;
  final List<String> options;
  final int? correctOptionId;
  final List<int> correctOptionIds;
  final bool allowsMultiple;
  final String? explanation;
  final int points;

  const Question({
    required this.id,
    required this.topicId,
    required this.order,
    required this.text,
    required this.type,
    required this.options,
    required this.correctOptionId,
    required this.correctOptionIds,
    required this.allowsMultiple,
    required this.explanation,
    required this.points,
  });

  factory Question.fromRow(Map<String, Object?> r) {
    List<int> correctIds = [];
    final rawIds = r['correct_option_ids'];
    if (rawIds is String && rawIds.isNotEmpty) {
      try {
        correctIds = (jsonDecode(rawIds) as List).cast<int>();
      } catch (_) {
        correctIds = [];
      }
    }
    final optionsRaw = r['options'];
    List<String> options = [];
    if (optionsRaw is String && optionsRaw.isNotEmpty) {
      try {
        options = (jsonDecode(optionsRaw) as List).cast<String>();
      } catch (_) {
        options = [];
      }
    }
    final correctId = r['correct_option_id'];
    String? explanation;
    final rawExplanation = r['explanation'];
    if (rawExplanation is String && rawExplanation.trim().isNotEmpty) {
      explanation = rawExplanation.trim();
    }
    return Question(
      id: r['id'] as int,
      topicId: (r['topic_id'] as int?) ?? 0,
      order: (r['question_order'] as int?) ?? 0,
      text: (r['text'] as String?) ?? '',
      type: QuestionType.from((r['type'] as String?) ?? 'poll'),
      options: options,
      correctOptionId: correctId is int ? correctId : null,
      correctOptionIds: correctIds,
      allowsMultiple: (r['allows_multiple_answers'] as int?) == 1,
      explanation: explanation,
      points: (r['points'] as int?) ?? 1,
    );
  }

  /// يحوّل سؤال عقد المحتوى البعيد (schemaVersion 1 مثل quran_general)
  /// إلى نموذج المحرك. [index] هو ترتيب السؤال داخل الاختبار ويصبح
  /// معرّفاً رقمياً اصطناعياً. أي مخالفة للعقد ترمي [FormatException].
  factory Question.fromRemote(Map<String, Object?> json, int index) {
    final id = json['id'];
    final prompt = json['prompt'];
    final rawOptions = json['options'];
    final correct = json['correctAnswer'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('سؤال بعيد: id نصي غير فارغ مطلوب');
    }
    if (prompt is! String || prompt.isEmpty) {
      throw const FormatException('سؤال بعيد: prompt نصي غير فارغ مطلوب');
    }
    if (rawOptions is! List ||
        rawOptions.length < 2 ||
        rawOptions.any((o) => o is! String || o.isEmpty)) {
      throw const FormatException(
          'سؤال بعيد: options قائمة نصوص بأقل من خيارين');
    }
    final options = rawOptions.cast<String>();
    if (correct is! int || correct < 0 || correct >= options.length) {
      throw const FormatException(
          'سؤال بعيد: correctAnswer فهرس خيار غير صالح');
    }
    final rawPoints = json['points'];
    final rawExplanation = json['explanation'];
    return Question(
      id: index + 1,
      topicId: 0,
      order: index,
      text: prompt,
      type: QuestionType.from((json['type'] as String?) ?? 'quiz'),
      options: options,
      correctOptionId: correct,
      correctOptionIds: [correct],
      allowsMultiple: false,
      explanation:
          rawExplanation is String && rawExplanation.trim().isNotEmpty
              ? rawExplanation.trim()
              : null,
      points: rawPoints is int && rawPoints >= 1 ? rawPoints : 1,
    );
  }

  /// هل الاختيارات المحددة (فهارس) صحيحة؟
  bool isCorrectFor(List<int> selections) {
    if (allowsMultiple && correctOptionIds.isNotEmpty) {
      final a = selections.toSet();
      final b = correctOptionIds.toSet();
      return a.length == b.length && a.containsAll(b);
    }
    return selections.length == 1 && selections.first == correctOptionId;
  }
}