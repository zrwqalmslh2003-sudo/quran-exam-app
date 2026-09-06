import 'package:flutter/material.dart';
import '../data/db.dart';
import '../data/quran_gen.dart';

class ExamScreen extends StatefulWidget {
  final int? quarterId;
  const ExamScreen({super.key, this.quarterId});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  final _excludedIds = <int>{};
  Ayah? _ayah;
  List<SurahPick>? _options;
  bool _loading = true;
  int? _selected;
  bool _revealed = false;
  int _score = 0;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _selected = null;
      _revealed = false;
    });
    final db = await AppDatabase.instance;
    final gen = QuranGenerator(db);
    final q = await buildAyahQuestion(gen, widget.quarterId ?? 1,
        excludeAyahIds: _excludedIds);
    if (q == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ayah = null;
      });
      return;
    }
    _excludedIds.add(q.ayah.id);
    if (!mounted) return;
    setState(() {
      _ayah = q.ayah;
      _options = q.options;
      _loading = false;
    });
  }

  void _choose(SurahPick pick) {
    if (_revealed || _ayah == null) return;
    final correct = pick.id == _ayah!.chapterId;
    setState(() {
      _selected = pick.id;
      _revealed = true;
      _attempts++;
      if (correct) _score++;
    });
  }

  String get _feedback {
    final ayah = _ayah!;
    final correct = _selected == ayah.chapterId;
    final tafseer = ayah.tafseer;
    final tail = tafseer != null && tafseer.isNotEmpty
        ? '\n\n${tafseer.length > 180 ? tafseer.substring(0, 180) + '…' : tafseer}'
        : '';
    return correct
        ? 'صحيح! ✅  ${ayah.surahName}' + tail
        : 'خطأ ❌  الإجابة الصحيحة: ${ayah.surahName}' + tail;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار الآيات'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(child: Text('$_score/$_attempts')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ayah == null
              ? const Center(child: Text('انتهت الآيات المتاحة في هذا الربع'))
              : buildQuestion(),
    );
  }

  Widget buildQuestion() {
    final ayah = _ayah!;
    final options = _options!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              ayah.text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, height: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...options.map((o) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _OptionTile(
                option: o,
                selected: _selected,
                revealed: _revealed,
                correct: o.id == ayah.chapterId,
                onTap: () => _choose(o),
              ),
            )),
        if (_revealed) ...[
          const SizedBox(height: 12),
          Text(_feedback, style: const TextStyle(fontSize: 16, height: 1.6)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.navigate_next),
            label: const Text('الاختبار التالي'),
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final SurahPick option;
  final int? selected;
  final bool revealed;
  final bool correct;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.selected,
    required this.revealed,
    required this.correct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? borderColor;
    if (revealed) {
      borderColor = correct ? Colors.green : (selected == option.id ? Colors.red : null);
    }
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderColor != null ? BorderSide(color: borderColor, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        title: Text(option.name, textAlign: TextAlign.center),
        onTap: revealed ? null : onTap,
        trailing: revealed && correct
            ? const Icon(Icons.check_circle, color: Colors.green)
            : (revealed && selected == option.id
                ? const Icon(Icons.cancel, color: Colors.red)
                : null),
      ),
    );
  }
}
