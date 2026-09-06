import 'package:flutter_test/flutter_test.dart';
import 'package:quran_exam_app/main.dart';

void main() {
  testWidgets('shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(const QuranExamApp());
    expect(find.text('اختبارات قالون'), findsOneWidget);
  });
}
