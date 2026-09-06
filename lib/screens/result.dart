import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final int score;
  final int totalPoints;
  final int questionCount;
  final String label;
  final VoidCallback onRetry;

  const ResultScreen({
    super.key,
    required this.score,
    required this.totalPoints,
    required this.questionCount,
    required this.label,
    required this.onRetry,
  });

  Color get _color {
    final p = _percentage;
    if (p >= 85) return Colors.green;
    if (p >= 60) return Colors.amber.shade700;
    return Colors.redAccent;
  }

  double get _percentage =>
      totalPoints == 0 ? 0 : (score / totalPoints * 100).clamp(0, 100);

  String get _msg {
    final p = _percentage;
    if (p >= 85) return 'ممتاز! 🎉';
    if (p >= 60) return 'جيد جداً 👏';
    if (p >= 50) return 'لا بأس، واصل';
    return 'تحتاج مراجعة 📚';
  }

  @override
  Widget build(BuildContext context) {
    final pct = _percentage;
    return Scaffold(
      appBar: AppBar(
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_msg,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 14,
                        backgroundColor: Colors.black12,
                        color: _color,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${pct.round()}%',
                            style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: _color)),
                        const SizedBox(height: 4),
                        Text('$score من $totalPoints',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('$questionCount سؤالاً',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.replay),
                label: const Text('إعادة الاختبار'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(220, 48),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                icon: const Icon(Icons.home),
                label: const Text('العودة للرئيسية'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(220, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}