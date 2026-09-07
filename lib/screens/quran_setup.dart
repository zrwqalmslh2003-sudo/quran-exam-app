import 'package:flutter/material.dart';
import '../data/quran_gen.dart';
import 'exam.dart';

class QuranSetupScreen extends StatefulWidget {
  final Quarter? quarter;
  const QuranSetupScreen({super.key, this.quarter});

  @override
  State<QuranSetupScreen> createState() => _QuranSetupScreenState();
}

class _QuranSetupScreenState extends State<QuranSetupScreen> {
  static const _sizes = [10, 15, 20, 25, 30];
  int _size = 15;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quarter = widget.quarter;
    final title = quarter == null ? 'القرآن كاملاً' : quarter.name;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: scheme.onPrimary.withOpacity(.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      quarter?.emoji ?? '📖',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إعداد الاختبار',
                          style: TextStyle(
                            color: scheme.onPrimary.withOpacity(.75),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          title,
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'عدد الأسئلة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              'اختر عدد الآيات التي تريد اختبار نفسك فيها',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withOpacity(.55),
                borderRadius: BorderRadius.circular(22),
              ),
              child: SegmentedButton<int>(
                segments: [
                  for (final size in _sizes)
                    ButtonSegment(value: size, label: Text('$size')),
                ],
                selected: {_size},
                onSelectionChanged: (value) => setState(() => _size = value.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant.withOpacity(.7)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'سيظهر زر للانتقال إلى السؤال التالي بعد الإجابة، وينتهي الاختبار عند إكمال العدد المحدد.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExamScreen(
                      quarterId: quarter?.id,
                      questionLimit: _size,
                      label: title,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('بدء الاختبار • $_size سؤالاً'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
