import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final int score;
  final int totalPoints;
  final int questionCount;
  final String label;
  final VoidCallback onRetry;
  const ResultScreen({super.key, required this.score, required this.totalPoints, required this.questionCount, required this.label, required this.onRetry});

  double get _percentage => totalPoints == 0 ? 0 : (score / totalPoints * 100).clamp(0, 100);
  Color get _color { final p = _percentage; if (p >= 85) return Colors.green; if (p >= 60) return Colors.amber.shade700; return Colors.redAccent; }
  String get _msg { final p = _percentage; if (p >= 85) return 'ممتاز! 🎉'; if (p >= 60) return 'أداء جيد جداً 👏'; if (p >= 50) return 'نتيجة طيبة، واصل'; return 'تحتاج إلى مزيد من المراجعة 📚'; }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = _percentage;
    return Scaffold(
      appBar: AppBar(title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis), automaticallyImplyLeading: false),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 30, 24, 30), child: Column(children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: _color.withOpacity(.12), shape: BoxShape.circle), child: Icon(Icons.emoji_events_rounded, color: _color, size: 34)),
        const SizedBox(height: 15),
        Text(_msg, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('نتيجة الاختبار', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 28),
        SizedBox(width: 190, height: 190, child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: 190, height: 190, child: CircularProgressIndicator(value: pct / 100, strokeWidth: 15, backgroundColor: scheme.surfaceContainerHighest, color: _color)),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${pct.round()}%', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: _color)), const SizedBox(height: 3), Text('$score من $totalPoints', style: const TextStyle(fontWeight: FontWeight.w600))]),
        ])),
        const SizedBox(height: 26),
        Row(children: [
          Expanded(child: _StatCard(icon: Icons.check_circle_outline, value: '$score', label: 'النقاط')),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(icon: Icons.quiz_outlined, value: '$questionCount', label: 'الأسئلة')),
        ]),
        const SizedBox(height: 28),
        FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.replay_rounded), label: const Text('إعادة الاختبار'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), icon: const Icon(Icons.home_rounded), label: const Text('العودة للرئيسية'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      ]))),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCard({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Column(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 7), Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, style: Theme.of(context).textTheme.bodySmall)])));
}
