import 'package:flutter/material.dart';
import '../data/db.dart';
import 'exam_cat.dart';

class RandomSetupScreen extends StatefulWidget {
  const RandomSetupScreen({super.key});
  @override
  State<RandomSetupScreen> createState() => _RandomSetupScreenState();
}

class _RandomSetupScreenState extends State<RandomSetupScreen> {
  static const _sizes = [10, 15, 20, 25, 30];
  int _size = 15;
  Future<List<Map<String, Object?>>> _categories() => AppDatabase.categories();

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('الاختبار العشوائي')),
          body: FutureBuilder<List<Map<String, Object?>>>(
            future: _categories(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              final cats = snap.data ?? const [];
              return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 30), children: [
                const _IntroCard(),
                const SizedBox(height: 28),
                const _SectionLabel(title: 'عدد الأسئلة', subtitle: 'اختر طول الاختبار المناسب لك'),
                const SizedBox(height: 12),
                _sizeChooser(),
                const SizedBox(height: 28),
                const _SectionLabel(title: 'نطاق الاختبار', subtitle: 'اختبر في كل التصنيفات أو اختر مجالاً محدداً'),
                const SizedBox(height: 12),
                _scopeTile(null, 'كل التصنيفات', 'أسئلة متنوعة من جميع التصنيفات', Icons.all_inclusive_rounded),
                ...cats.asMap().entries.map((e) {
                  final c = e.value;
                  return _scopeTile(c['id'] as int, '${c['emoji'] ?? ''} ${c['name'] ?? ''}', 'أسئلة من هذا التصنيف فقط', Icons.category_outlined);
                }),
              ]);
            },
          ),
        ),
      );

  Widget _sizeChooser() => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.55), borderRadius: BorderRadius.circular(22)),
        child: SegmentedButton<int>(
          segments: [for (final s in _sizes) ButtonSegment(value: s, label: Text('$s'))],
          selected: {_size},
          onSelectionChanged: (s) => setState(() => _size = s.first),
          showSelectedIcon: false,
          style: ButtonStyle(shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
        ),
      );

  Widget _scopeTile(int? id, String name, String subtitle, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _start(id, name),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: scheme.outlineVariant.withOpacity(.7))),
            child: Row(children: [
              Container(width: 49, height: 49, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: scheme.onPrimaryContainer)),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)), const SizedBox(height: 3), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)])),
              Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: scheme.primary),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _start(int? categoryId, String name) async {
    final questions = await AppDatabase.randomQuestions(_size, categoryId: categoryId);
    if (!mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد أسئلة كافية في هذا النطاق')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ExamCatScreen(topicId: 0, label: 'عشوائي — $name', questions: questions)));
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionLabel({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
    const SizedBox(height: 4),
    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
  ]);
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(27)),
      child: Row(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: scheme.onPrimary.withOpacity(.12), shape: BoxShape.circle), child: Icon(Icons.shuffle_rounded, size: 27, color: scheme.onPrimary)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('اختبار بلا ترتيب', style: TextStyle(color: scheme.onPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('أنشئ اختباراً سريعاً من الأسئلة المتاحة', style: TextStyle(color: scheme.onPrimary.withOpacity(.78), height: 1.45)),
        ])),
      ]),
    );
  }
}
