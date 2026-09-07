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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الاختبار العشوائي')),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: _categories(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final cats = snap.data ?? const [];
            return ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
              _IntroCard(),
              const SizedBox(height: 22),
              const Text('عدد الأسئلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('اختر طول الاختبار المناسب لك', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              _sizeChooser(),
              const SizedBox(height: 26),
              const Text('نطاق الاختبار', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('يمكنك الاختبار في كل التصنيفات أو تصنيف محدد', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              _scopeTile(null, 'كل التصنيفات', 'أسئلة متنوعة من جميع التصنيفات', Icons.all_inclusive_rounded),
              ...cats.map((c) => _scopeTile(c['id'] as int, '${c['emoji'] ?? ''} ${c['name'] ?? ''}', 'أسئلة من هذا التصنيف فقط', Icons.category_outlined)),
            ]);
          },
        ),
      );

  Widget _sizeChooser() => Card(child: Padding(padding: const EdgeInsets.all(8), child: SegmentedButton<int>(segments: [for (final s in _sizes) ButtonSegment(value: s, label: Text('$s'), icon: const Icon(Icons.help_outline, size: 16))], selected: {_size}, onSelectionChanged: (s) => setState(() => _size = s.first), showSelectedIcon: false)));

  Widget _scopeTile(int? id, String name, String subtitle, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () => _start(id, name), child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: scheme.onPrimaryContainer)),
      const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 3), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)])),
      Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: scheme.outline),
    ]))));
  }

  Future<void> _start(int? categoryId, String name) async {
    final questions = await AppDatabase.randomQuestions(_size, categoryId: categoryId);
    if (!mounted) return;
    if (questions.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد أسئلة كافية في هذا النطاق'))); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ExamCatScreen(topicId: 0, label: 'عشوائي — $name', questions: questions)));
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(24)), child: Row(children: [
      Icon(Icons.shuffle_rounded, size: 44, color: scheme.onPrimaryContainer), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('اختبار بلا ترتيب', style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('أنشئ اختباراً سريعاً من الأسئلة المتاحة', style: TextStyle(color: scheme.onPrimaryContainer.withOpacity(.78), height: 1.4))]))
    ]));
  }
}
