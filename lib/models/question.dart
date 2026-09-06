import 'dart:convert';

enum QuestionType {
  poll,
  quiz,
  trueFalse,
  other;

  static QuestionType from(String s) => switch (s) {
        'poll' => QuestionType.poll,
        'quiz' => QuestionType.quiz,
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
    final explanation = r['explanation'];
    final hasExplanation =
        explanation is String && explanation.trim().isNotEmpty;
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
      explanation: hasExplanation ? (explanation as String).trim() : null,
      points: (r['points'] as int?) ?? 1,
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