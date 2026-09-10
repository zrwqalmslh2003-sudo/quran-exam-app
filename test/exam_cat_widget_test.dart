import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/models/question.dart';
import 'package:quran_exam_app/screens/exam_cat.dart';

void main() {
  testWidgets('سؤال وحيد الإجابة: النقر على خيار يكشف التقييم دون زر تأكيد',
      (tester) async {
    const question = Question(
      id: 1,
      topicId: 1,
      order: 0,
      text: 'ما عاصمة المملكة العربية السعودية؟',
      type: QuestionType.quiz,
      options: ['الرياض', 'جدة', 'مكة المكرمة', 'الدمام'],
      correctOptionId: 0,
      correctOptionIds: [0],
      allowsMultiple: false,
      explanation: null,
      points: 1,
    );

    await tester.pumpWidget(const MaterialApp(
      home: ExamCatScreen(
        topicId: 1,
        label: 'اختبار تجريبي',
        questions: [question],
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('تأكيد الإجابة'), findsOneWidget,
        reason: 'قبل الاختيار يظهر زر التأكيد بوضعه الافتراضي');

    await tester.tap(find.text('الرياض'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('تأكيد الإجابة'), findsNothing,
        reason: 'اختيار الإجابة الواحدة يجب أن يكشف التقييم فوراً دون مرحلة تأكيد');
    expect(find.text('إجابة صحيحة'), findsOneWidget,
        reason: 'رد الفعل (الصحيح/الخطأ) يظهر مباشرة بعد النقر');
    expect(find.text('عرض النتيجة'), findsOneWidget,
        reason: 'بعد الكشف يُتاح الانتقال للنتيجة');
  });
}