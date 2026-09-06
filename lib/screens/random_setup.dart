import 'package:flutter/material.dart';
import '../data/db.dart';
import 'exam_cat.dart';

/// اختيار عدد الأسئلة ثم النطاق للاختبار العشوائي.
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاختبار العشوائي')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _categories(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final cats = snap.data ?? const [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('اختر عدد الأسئلة:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _sizeChooser(),
              const SizedBox(height: 24),
              Text('اختر النطاق:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _scopeTile(null, '🔥 كل التصنيفات', 'توزيع متوازن بينها'),
              ...cats.map((c) => _scopeTile(
                  c['id'] as int,
                  '${c['emoji'] ?? ''} ${c['name'] ?? ''}',
                  'من هذا التصنيف فقط')),
            ],
          );
        },
      ),
    );
  }

  Widget _sizeChooser() {
    return SegmentedButton<int>(
      segments: [for (final s in _sizes) ButtonSegment(value: s, label: Text('$s'))],
      selected: {_size},
      onSelectionChanged: (sel) => setState(() => _size = sel.first),
    );
  }

  Widget _scopeTile(int? id, String name, String subtitle) {
    return Card(
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => _start(id, name),
      ),
    );
  }

  Future<void> _start(int? categoryId, String name) async {
    final questions = await AppDatabase.randomQuestions(_size,
        categoryId: categoryId);
    if (!mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد أسئلة كافية في هذا النطاق')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamCatScreen(
          topicId: 0,
          label: 'عشوائي ($name)',
          questions: questions,
        ),
      ),
    );
  }
}