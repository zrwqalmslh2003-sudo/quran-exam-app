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
  String get _msg { final p = _percentage; if (p >= 85) return 'أداء ممتاز'; if (p >= 60) return 'أداء جيد جداً'; if (p >= 50) return 'نتيجة طيبة، واصل'; return 'تحتاج إلى مزيد من المراجعة'; }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = _percentage;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('النتيجة', maxLines: 1, overflow: TextOverflow.ellipsis), automaticallyImplyLeading: false),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(28)),
              child: Column(children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(color: scheme.onPrimary.withOpacity(.12), shape: BoxShape.circle), child: Icon(Icons.emoji_events_rounded, color: scheme.onPrimary, size: 30)),
                const SizedBox(height: 13),
                Text(_msg, style: TextStyle(color: scheme.onPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onPrimary.withOpacity(.75), fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(26), border: Border.all(color: scheme.outlineVariant.withOpacity(.7))),
              child: Column(children: [
                SizedBox(width: 170, height: 170, child: Stack(alignment: Alignment.center, children: [
                  SizedBox(width: 170, height: 170, child: CircularProgressIndicator(value: pct / 100, strokeWidth: 13, backgroundColor: scheme.surfaceContainerHighest, color: _color)),
                  Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${pct.round()}%', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _color)), const SizedBox(height: 2), Text('$score من $totalPoints', style: const TextStyle(fontWeight: FontWeight.w700))]),
                ])),
                const SizedBox(height: 15),
                Text('نتيجة الاختبار', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _StatCard(icon: Icons.check_circle_outline_rounded, value: '$score', label: 'النقاط')),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(icon: Icons.quiz_outlined, value: '$questionCount', label: 'الأسئلة')),
            ]),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.replay_rounded), label: const Text('إعادة الاختبار'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: const StadiumBorder()))),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), icon: const Icon(Icons.home_rounded), label: const Text('العودة للرئيسية'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: const StadiumBorder()))),
          ]),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCard({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: scheme.outlineVariant.withOpacity(.7))),
      child: Column(children: [Icon(icon, color: scheme.primary), const SizedBox(height: 7), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, style: Theme.of(context).textTheme.bodySmall)]),
    );
  }
}
