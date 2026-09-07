import 'package:flutter/material.dart';
import '../data/db.dart';
import '../data/quran_gen.dart';
import 'result.dart';

class ExamScreen extends StatefulWidget {
  final int? quarterId;
  final int questionLimit;
  final String? label;

  const ExamScreen({
    super.key,
    this.quarterId,
    this.questionLimit = 15,
    this.label,
  });

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
    if (_attempts >= widget.questionLimit) {
      _finish();
      return;
    }
    setState(() {
      _loading = true;
      _selected = null;
      _revealed = false;
    });
    final db = await AppDatabase.instance;
    final gen = QuranGenerator(db);
    final q = await buildAyahQuestion(
      gen,
      widget.quarterId ?? 1,
      excludeAyahIds: _excludedIds,
    );
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

  void _finish() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          score: _score,
          totalPoints: _attempts,
          questionCount: _attempts,
          label: widget.label ?? 'اختبار الآيات',
          onRetry: () {
            Navigator.pop(context);
            setState(() {
              _excludedIds.clear();
              _ayah = null;
              _options = null;
              _score = 0;
              _attempts = 0;
            });
            _load();
          },
        ),
      ),
    );
  }

  bool get _correct => _ayah != null && _selected == _ayah!.chapterId;
  String get _feedback => _correct
      ? 'أحسنت! إجابة صحيحة'
      : 'الإجابة الصحيحة: ${_ayah!.surahName}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = widget.questionLimit == 0
        ? 0.0
        : _attempts / widget.questionLimit;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.label ?? 'اختبار الآيات'),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Center(
                child: Text(
                  '$_attempts / ${widget.questionLimit}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(5),
            child: LinearProgressIndicator(value: progress, minHeight: 5),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _ayah == null
                ? const _EndState()
                : _buildQuestion(scheme),
      ),
    );
  }

  Widget _buildQuestion(ColorScheme scheme) {
    final ayah = _ayah!;
    final options = _options!;
    final number = _attempts + 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'السؤال $number',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '$number / ${widget.questionLimit}',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(19, 20, 19, 22),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.outlineVariant.withOpacity(.7)),
          ),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.format_quote_rounded,
                    color: scheme.primary, size: 27),
              ),
              const SizedBox(height: 15),
              Text(
                ayah.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 23, height: 1.9, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'إلى أي سورة تنتمي هذه الآية؟',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...options.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OptionTile(
                  index: e.key,
                  option: e.value,
                  selected: _selected,
                  revealed: _revealed,
                  correct: e.value.id == ayah.chapterId,
                  onTap: () => _choose(e.value),
                ),
              ),
            ),
        if (_revealed) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_correct ? Colors.green : Colors.redAccent)
                  .withOpacity(.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (_correct ? Colors.green : Colors.redAccent)
                    .withOpacity(.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _correct
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
                      color: _correct ? Colors.green : Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _feedback,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                if (ayah.tafseer != null && ayah.tafseer!.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text('فائدة', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(
                    ayah.tafseer!.length > 220
                        ? '${ayah.tafseer!.substring(0, 220)}…'
                        : ayah.tafseer!,
                    style: const TextStyle(height: 1.6),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _attempts >= widget.questionLimit ? _finish : _load,
            icon: Icon(_attempts >= widget.questionLimit
                ? Icons.flag_rounded
                : Icons.arrow_back_rounded),
            label: Text(_attempts >= widget.questionLimit
                ? 'عرض النتيجة'
                : 'السؤال التالي'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final int index;
  final SurahPick option;
  final int? selected;
  final bool revealed;
  final bool correct;
  final VoidCallback onTap;

  const _OptionTile({
    required this.index,
    required this.option,
    required this.selected,
    required this.revealed,
    required this.correct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = selected == option.id;
    Color border = scheme.outlineVariant;
    Color fill = scheme.surface;
    IconData? trailing;
    if (revealed && correct) {
      border = Colors.green;
      fill = Colors.green.withOpacity(.07);
      trailing = Icons.check_circle_rounded;
    } else if (revealed && isSelected) {
      border = Colors.redAccent;
      fill = Colors.redAccent.withOpacity(.07);
      trailing = Icons.cancel_rounded;
    } else if (isSelected) {
      border = scheme.primary;
      fill = scheme.primary.withOpacity(.07);
    }
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: revealed ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: border,
              width: isSelected || (revealed && correct) ? 1.7 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  String.fromCharCode(0x0661 + index),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              if (trailing != null) Icon(trailing, color: border),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndState extends StatelessWidget {
  const _EndState();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_rounded,
                  size: 38,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              const Text('انتهت الآيات المتاحة',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              const Text('لا توجد آيات أخرى في هذا النطاق.',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
