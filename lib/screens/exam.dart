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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _selected = null; _revealed = false; });
    final db = await AppDatabase.instance;
    final gen = QuranGenerator(db);
    final q = await buildAyahQuestion(gen, widget.quarterId ?? 1, excludeAyahIds: _excludedIds);
    if (q == null) { if (!mounted) return; setState(() { _loading = false; _ayah = null; }); return; }
    _excludedIds.add(q.ayah.id);
    if (!mounted) return;
    setState(() { _ayah = q.ayah; _options = q.options; _loading = false; });
  }

  void _choose(SurahPick pick) {
    if (_revealed || _ayah == null) return;
    final correct = pick.id == _ayah!.chapterId;
    setState(() { _selected = pick.id; _revealed = true; _attempts++; if (correct) _score++; });
  }

  bool get _correct => _ayah != null && _selected == _ayah!.chapterId;
  String get _feedback => _correct ? 'أحسنت! إجابة صحيحة' : 'الإجابة الصحيحة: ${_ayah!.surahName}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('اختبار الآيات'), actions: [Padding(padding: const EdgeInsetsDirectional.only(end: 18), child: Center(child: Text('$_score / $_attempts', style: const TextStyle(fontWeight: FontWeight.w800))))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _ayah == null ? const _EndState() : _buildQuestion(scheme),
    );
  }

  Widget _buildQuestion(ColorScheme scheme) {
    final ayah = _ayah!;
    final options = _options!;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
      Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(10)), child: const Text('اختبار مواضع السور', style: TextStyle(fontWeight: FontWeight.w800))),
        const Spacer(),
        Text('$_attempts سؤالاً', style: Theme.of(context).textTheme.bodySmall),
      ]),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.fromLTRB(18, 22, 18, 24), child: Column(children: [
        Icon(Icons.format_quote_rounded, color: scheme.primary, size: 30),
        const SizedBox(height: 12),
        Text(ayah.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, height: 1.85, fontWeight: FontWeight.w600)),
      ]))),
      const SizedBox(height: 18),
      const Text('إلى أي سورة تنتمي هذه الآية؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      ...options.map((o) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _OptionTile(option: o, selected: _selected, revealed: _revealed, correct: o.id == ayah.chapterId, onTap: () => _choose(o)))),
      if (_revealed) ...[
        const SizedBox(height: 4),
        Card(color: _correct ? Colors.green.withOpacity(.09) : Colors.red.withOpacity(.08), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(_correct ? Icons.check_circle_rounded : Icons.info_rounded, color: _correct ? Colors.green : Colors.redAccent), const SizedBox(width: 8), Expanded(child: Text(_feedback, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)))]),
          if (ayah.tafseer != null && ayah.tafseer!.isNotEmpty) ...[const Divider(height: 24), const Text('فائدة', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(ayah.tafseer!.length > 220 ? '${ayah.tafseer!.substring(0, 220)}…' : ayah.tafseer!, style: const TextStyle(height: 1.6))],
        ]))),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.arrow_back_rounded), label: const Text('الآية التالية'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      ],
    ]);
  }
}

class _OptionTile extends StatelessWidget {
  final SurahPick option;
  final int? selected;
  final bool revealed;
  final bool correct;
  final VoidCallback onTap;
  const _OptionTile({required this.option, required this.selected, required this.revealed, required this.correct, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = selected == option.id;
    Color border = scheme.outlineVariant;
    Color? fill;
    if (revealed && correct) { border = Colors.green; fill = Colors.green.withOpacity(.08); }
    else if (revealed && isSelected) { border = Colors.redAccent; fill = Colors.redAccent.withOpacity(.08); }
    else if (isSelected) { border = scheme.primary; fill = scheme.primary.withOpacity(.08); }
    return Material(color: fill ?? scheme.surface, borderRadius: BorderRadius.circular(17), child: InkWell(borderRadius: BorderRadius.circular(17), onTap: revealed ? null : onTap, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), border: Border.all(color: border, width: isSelected || (revealed && correct) ? 1.7 : 1)), child: Row(children: [
      CircleAvatar(radius: 20, backgroundColor: isSelected ? scheme.primary : scheme.surfaceContainerHighest, child: Icon(Icons.menu_book_rounded, size: 19, color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant)),
      const SizedBox(width: 12), Expanded(child: Text(option.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
      if (revealed) Icon(correct ? Icons.check_circle_rounded : isSelected ? Icons.cancel_rounded : Icons.radio_button_unchecked, color: correct ? Colors.green : isSelected ? Colors.redAccent : scheme.outline),
    ])));
  }
}

class _EndState extends StatelessWidget {
  const _EndState();
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified_rounded, size: 62, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 14), const Text('انتهت الآيات المتاحة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 6), const Text('لا توجد آيات أخرى في هذا النطاق.', textAlign: TextAlign.center)]));
}
