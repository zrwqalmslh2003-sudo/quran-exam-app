import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/data/question_picker.dart';

Map<String, Object?> _question(int id, int topicId) => {
      'id': id,
      'topic_id': topicId,
      'question_order': id,
      'text': 'سؤال $id',
      'type': 'quiz',
      'options': '["أ", "ب"]',
      'correct_option_id': 0,
      'correct_option_ids': '[0]',
      'allows_multiple_answers': 0,
      'points': 1,
    };

void main() {
  test('fallback لا يعيد سؤالًا من تصنيف معطل', () {
    final result = QuestionPicker.pick(
      categories: [
        {'id': 1, 'is_active': 1},
        {'id': 2, 'is_active': 0},
      ],
      subcategories: [
        {'id': 10, 'category_id': 1, 'is_active': 1},
        {'id': 20, 'category_id': 2, 'is_active': 1},
      ],
      topics: [
        {'id': 100, 'subcategory_id': 10, 'is_active': 1},
        {'id': 200, 'subcategory_id': 20, 'is_active': 1},
      ],
      questions: [_question(1, 100), _question(2, 200)],
      count: 2,
    );

    expect(result.map((q) => q.id), [1]);
  });

  test('fallback لا يعيد سؤالًا من موضوع معطل عند نقص الأسئلة', () {
    final result = QuestionPicker.pick(
      categories: [
        {'id': 1, 'is_active': 1},
      ],
      subcategories: [
        {'id': 10, 'category_id': 1, 'is_active': 1},
      ],
      topics: [
        {'id': 100, 'subcategory_id': 10, 'is_active': 1},
        {'id': 200, 'subcategory_id': 10, 'is_active': 0},
      ],
      questions: [_question(1, 100), _question(2, 200)],
      count: 5,
    );

    expect(result.map((q) => q.id), [1]);
  });
}
