import 'package:flutter/material.dart';
import '../data/exam_repository.dart';
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
  List<AyahQuestion>? _questions;
  int _index = 0;
  bool _loading = true;
  int? _selected;
  bool _revealed = false;
  int _score = 0;
  int _attempts = 0;

  static const _background = Color(0xFF081126);
  static const _surface = Color(0xFF141E3B);
  static const _purple = Color(0xFF7B4DFF);

  Ayah? get _ayah => _index < (_questions?.length ?? 0)
      ? _questions![_index].ayah
      : null;

  List<SurahPick>? get _options => _index < (_questions?.length ?? 0)
      ? _questions![_index].options
      : null;

  bool get _last => _index + 1 >= (_questions?.length ?? 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await ExamRepository.instance;
    final list = await repo.ayahExam(widget.quarterId ?? 1,
        limit: widget.questionLimit);
    if (!mounted) return;
    setState(() {
      _questions = list;
      _index = 0;
      _selected = null;
      _revealed = false;
      _loading = false;
    });
  }

  void _next() {
    setState(() {
      _index++;
      _selected = null;
      _revealed = false;
    });
  }

  void _select(SurahPick pick) {
    if (_revealed || _loading) return;
    setState(() => _selected = pick.id);
  }

  void _confirm() {
    if (_selected == null || _ayah == null || _revealed) return;

    final correct = _selected == _ayah!.chapterId;
    setState(() {
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
              _questions = null;
              _index = 0;
              _score = 0;
              _attempts = 0;
              _loading = true;
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
    final total = _questions?.length ?? widget.questionLimit;
    final progress = total == 0 ? 0.0 : _attempts / total;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF101A39), Color(0xFF071025)],
            ),
          ),
          child: SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _purple),
                  )
                : _ayah == null
                    ? const _EndState()
                    : Column(
                        children: [
                          _buildHeader(progress, total),
                          Expanded(child: _buildQuestion()),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

Widget _buildHeader(double progress, int total) {
  final number = _attempts + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Column(
        children: [
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.maybePop(context),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'اختيارات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        ' وأسئلة',
                        style: TextStyle(
                          color: Color(0xFF8B63FF),
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7751FF),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(15),
                            topRight: Radius.circular(15),
                            bottomLeft: Radius.circular(15),
                            bottomRight: Radius.circular(5),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 29,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'اختر إجابتك .. واختبر معلوماتك',
                    style: TextStyle(
                      color: Color(0xFFB6BED3),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '$number / $total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFF293351),
                    valueColor: const AlwaysStoppedAnimation(_purple),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final ayah = _ayah!;
    final options = _options!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
          decoration: BoxDecoration(
            color: _surface.withOpacity(.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF4E55A3), width: 1.3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.topStart,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0x332F65FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFF7189FF),
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                ayah.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  height: 1.9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'إلى أي سورة تنتمي هذه الآية؟',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        ...options.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: _OptionTile(
              index: entry.key,
              option: entry.value,
              selected: _selected,
              revealed: _revealed,
              correct: entry.value.id == ayah.chapterId,
              onTap: () => _select(entry.value),
            ),
          ),
        ),
        if (_revealed) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: (_correct ? Colors.greenAccent : Colors.redAccent)
                  .withOpacity(.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (_correct ? Colors.greenAccent : Colors.redAccent)
                    .withOpacity(.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _correct
                      ? Icons.check_circle_rounded
                      : Icons.info_rounded,
                  color: _correct ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _feedback,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _ConfirmButton(
          enabled: _selected != null,
          revealed: _revealed,
          isLast: _last,
          onPressed: _revealed
              ? (_last ? _finish : _next)
              : _confirm,
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF202B4A),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
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

  static const _accent = [
    Color(0xFF4C7DFF),
    Color(0xFF25C987),
    Color(0xFF8A4DFF),
    Color(0xFFFF8B22),
  ];

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == option.id;
    final accent = _accent[index % _accent.length];

    Color border = accent.withOpacity(.9);
    Color fill = const Color(0xFF172340);

    if (revealed && correct) {
      border = Colors.greenAccent;
      fill = Colors.green.withOpacity(.12);
    } else if (revealed && isSelected) {
      border = Colors.redAccent;
      fill = Colors.red.withOpacity(.12);
    } else if (isSelected) {
      fill = accent.withOpacity(.18);
      border = accent;
    }

    final letter = String.fromCharCode(65 + index);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: revealed ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 78,
          padding: const EdgeInsetsDirectional.only(start: 18, end: 10),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: border,
              width: isSelected || (revealed && correct) ? 1.8 : 1.1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option.name,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(.25),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (revealed && (correct || isSelected)) ...[
                const SizedBox(width: 8),
                Icon(
                  correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: correct ? Colors.greenAccent : Colors.redAccent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final bool enabled;
  final bool revealed;
  final bool isLast;
  final VoidCallback onPressed;

  const _ConfirmButton({
    required this.enabled,
    required this.revealed,
    required this.isLast,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled || revealed;

    return Opacity(
      opacity: active ? 1 : .45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8A4DFF), Color(0xFF2D86FF)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x403D6FFF),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: SizedBox(
          height: 62,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: active ? onPressed : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    revealed
                        ? (isLast ? 'عرض النتيجة' : 'السؤال التالي')
                        : 'تأكيد',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    revealed && isLast
                        ? Icons.flag_rounded
                        : Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
            ),
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
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  color: Color(0x332D86FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 40,
                  color: Color(0xFF6F8BFF),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'انتهت الآيات المتاحة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'لا توجد آيات أخرى في هذا النطاق.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB6BED3)),
              ),
            ],
          ),
        ),
      );
}
