import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/data/exam_repository.dart';
import 'package:quran_exam_app/data/quran_gen.dart';
import 'package:quran_exam_app/models/question.dart';
import 'package:quran_exam_app/screens/exam.dart';

class _FakeExamRepository implements ExamRepository {
  int loadCount = 0;

  @override
  Future<List<Question>> questionsForTopic(int topicId) async => [];

  @override
  Future<List<Question>> randomQuestions(int count, {int? categoryId}) async =>
      [];

  @override
  Future<List<AyahQuestion>> ayahExam(int quarterId,
      {required int limit}) async {
    loadCount++;
    const q1 = [
      SurahPick(2, 'البقرة'),
      SurahPick(3, 'آل عمران'),
      SurahPick(1, 'الفاتحة'),
      SurahPick(4, 'النساء'),
    ];
    const q2 = [
      SurahPick(1, 'الفاتحة'),
      SurahPick(2, 'البقرة'),
      SurahPick(4, 'النساء'),
      SurahPick(3, 'آل عمران'),
    ];
    return const [
      AyahQuestion(Ayah(1, 2, 'البقرة', 1, 'الم ١', null), q1),
      AyahQuestion(
          Ayah(2, 1, 'الفاتحة', 1, 'بِسْمِ اللهِ الرَّحْمَٰنِ الرَّحِيمِ',
              null),
          q2),
    ].take(limit).toList();
  }
}

Future<void> pumpUntil(WidgetTester tester, Finder finder,
    {int maxTries = 40}) async {
  for (var i = 0; i < maxTries; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
}

void main() {
  setUp(() => ExamRepository.debugSetInstanceForTest(null));

  testWidgets('إعادة الاختبار بعد عرض النتيجة تعمل دون استثناءات الانحياز',
      (tester) async {
    final repo = _FakeExamRepository();
    ExamRepository.debugSetInstanceForTest(repo);

    await tester.pumpWidget(const MaterialApp(
      home: ExamScreen(quarterId: 1, questionLimit: 2, label: 'اختبار الآيات'),
    ));

    await pumpUntil(tester, find.text('تأكيد'));
    expect(tester.takeException(), isNull, reason: 'تحميل الاختبار دون أخطاء');

    Future<void> answerQuestion({required bool isLast}) async {
      await tester.ensureVisible(find.text('A'));
      await tester.tap(find.text('A'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.ensureVisible(find.text('تأكيد'));
      await tester.tap(find.text('تأكيد'));
      await tester.pump(const Duration(milliseconds: 50));
      final next = isLast ? 'عرض النتيجة' : 'السؤال التالي';
      await tester.ensureVisible(find.text(next));
      await tester.tap(find.text(next));
      await tester.pump(const Duration(milliseconds: 50));
    }

    await answerQuestion(isLast: false);
    await answerQuestion(isLast: true);

    await pumpUntil(tester, find.text('النتيجة'));
    expect(find.text('النتيجة'), findsOneWidget,
        reason: 'يصل المستخدم لشاشة النتيجة');

    await tester.ensureVisible(find.text('إعادة الاختبار'));
    await tester.tap(find.text('إعادة الاختبار'));

    await pumpUntil(tester, find.text('تأكيد'));

    expect(tester.takeException(), isNull,
        reason: 'إعادة الاختبار يجب ألا ترمي setState-after-dispose أو أي استثناء');
    expect(repo.loadCount, 2,
        reason: 'إعادة الاختبار تُعيد تحميل الأسئلة من جديد');
    expect(find.text('A'), findsWidgets,
        reason: 'شاشة الاختبار عادت تفاعلية وتعرض الخيارات مجدداً');
  });
}