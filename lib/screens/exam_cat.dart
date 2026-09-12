import 'package:flutter/material.dart';
import '../data/exam_catalog.dart';
import '../data/exam_repository.dart';
import '../models/question.dart';
import 'result.dart';

class ExamCatScreen extends StatefulWidget {
  final int? topicId;
  final String? examId;
  final String label;
  final List<Question>? questions;
  const ExamCatScreen({super.key, this.topicId, required this.label, this.examId, this.questions});
  @override
  State<ExamCatScreen> createState() => _ExamCatScreenState();
}

class _ExamCatScreenState extends State<ExamCatScreen> {
  late Future<List<Question>> _future;
  List<Question> _questions = [];
  int _index = 0;
  int _score = 0;
  final List<int> _selection = [];
  bool _revealed = false;
  bool _answeredCorrectly = false;

  @override
  void initState() {
    super.initState();
    _future = widget.questions != null ? Future.value(widget.questions) : _load();
  }

  Future<List<Question>> _load() async {
    final repo = await ExamRepository.instance;
    if (widget.examId != null) {
      if (repo is ExamCatalogRepository) {
        final list =
            await (repo as ExamCatalogRepository).questionsForExam(widget.examId!);
        _questions = list;
        return list;
      }
      _questions = const [];
      return const [];
    }
    final topicId = widget.topicId;
    if (topicId == null) {
      _questions = const [];
      return const [];
    }
    final list = await repo.questionsForTopic(topicId);
    _questions = list;
    return list;
  }

  int get _totalPoints => _questions.fold<int>(0, (s, q) => s + q.points);
  Question get _question => _questions[_index];
  bool get _isMulti => _question.allowsMultiple;
  bool get _last => _index + 1 >= _questions.length;

  void _reset() => setState(() {
        _index = 0;
        _score = 0;
        _selection.clear();
        _revealed = false;
        _answeredCorrectly = false;
      });

  void _toggle(int i) {
    if (_revealed) return;
    setState(() {
      if (_isMulti) {
        _selection.contains(i) ? _selection.remove(i) : _selection.add(i);
      } else {
        _selection
          ..clear()
          ..add(i);
        _answeredCorrectly = _question.isCorrectFor(_selection);
        _revealed = true;
        if (_answeredCorrectly) _score += _question.points;
      }
    });
  }

  void _confirm() {
    if (_revealed || _selection.isEmpty) return;
    final correct = _question.isCorrectFor(_selection);
    setState(() {
      _answeredCorrectly = correct;
      _revealed = true;
      if (correct) _score += _question.points;
    });
  }

  void _next() {
    if (_last) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            score: _score,
            totalPoints: _totalPoints,
            questionCount: _questions.length,
            label: widget.label,
            onRetry: () {
              Navigator.pop(context);
              _reset();
            },
          ),
        ),
      );
      return;
    }
    setState(() {
      _index++;
      _selection.clear();
      _revealed = false;
      _answeredCorrectly = false;
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: FutureBuilder<List<Question>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.done && snap.hasData) _questions = snap.data!;
            final body = snap.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : _questions.isEmpty
                    ? const Center(child: Text('لا توجد أسئلة في هذا الاختبار'))
                    : _body();
            final progress = _questions.isEmpty ? 0.0 : (_index + (_revealed ? 1 : 0)) / _questions.length;
            return Scaffold(
              appBar: AppBar(
                title: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                actions: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 16),
                    child: Center(child: Text('$_score / $_totalPoints', style: const TextStyle(fontWeight: FontWeight.w900))),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(5),
                  child: LinearProgressIndicator(value: progress, minHeight: 5),
                ),
              ),
              body: body,
            );
          },
        ),
      );

  Widget _body() {
    final q = _question;
    final scheme = Theme.of(context).colorScheme;
    final progress = (_index + 1) / _questions.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(999)),
            child: Text('السؤال ${_index + 1}', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w900)),
          ),
          const Spacer(),
          Text('${(_index + 1)} / ${_questions.length}', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: scheme.outlineVariant.withOpacity(.7)),
          ),
          child: Column(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: scheme.primary.withOpacity(.10), shape: BoxShape.circle), child: Icon(Icons.help_outline_rounded, color: scheme.primary)),
            const SizedBox(height: 14),
            Text(q.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, height: 1.75, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, minHeight: 4)),
          ]),
        ),
        if (_isMulti && !_revealed) ...[
          const SizedBox(height: 12),
          Row(children: [Icon(Icons.touch_app_rounded, size: 17, color: scheme.primary), const SizedBox(width: 6), Text('يمكن اختيار أكثر من إجابة', style: Theme.of(context).textTheme.bodySmall)]),
        ],
        const SizedBox(height: 12),
        ...q.options.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildOption(e.key, e.value, q))),
        if (!_revealed) ...[
          const SizedBox(height: 2),
          FilledButton.icon(
            onPressed: _selection.isEmpty ? null : _confirm,
            icon: const Icon(Icons.check_rounded),
            label: const Text('تأكيد الإجابة'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: const StadiumBorder()),
          ),
        ],
        if (_revealed) ...[
          const SizedBox(height: 4),
          _FeedbackCard(correct: _answeredCorrectly, text: _statusText(), explanation: q.explanation),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _next,
            icon: Icon(_last ? Icons.flag_rounded : Icons.arrow_back_rounded),
            label: Text(_last ? 'عرض النتيجة' : 'السؤال التالي'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: const StadiumBorder()),
          ),
        ],
      ],
    );
  }

  String _statusText() {
    final answer = _answerLabel(_question);
    return _answeredCorrectly ? 'إجابة صحيحة' : 'الإجابة الصحيحة: $answer';
  }

  String _answerLabel(Question q) {
    if (q.allowsMultiple && q.correctOptionIds.isNotEmpty) return q.correctOptionIds.map((i) => q.options[i]).join('، ');
    final i = q.correctOptionId;
    if (i != null && i >= 0 && i < q.options.length) return q.options[i];
    return '—';
  }

  Widget _buildOption(int idx, String opt, Question q) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selection.contains(idx);
    final isCorrect = q.allowsMultiple ? q.correctOptionIds.contains(idx) : q.correctOptionId == idx;
    Color border = scheme.outlineVariant;
    Color fill = scheme.surface;
    IconData? trailing;
    if (_revealed && isCorrect) {
      border = Colors.green;
      fill = Colors.green.withOpacity(.07);
      trailing = Icons.check_circle_rounded;
    } else if (_revealed && selected) {
      border = Colors.redAccent;
      fill = Colors.redAccent.withOpacity(.07);
      trailing = Icons.cancel_rounded;
    } else if (selected) {
      border = scheme.primary;
      fill = scheme.primary.withOpacity(.07);
    }

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _revealed ? null : () => _toggle(idx),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: border, width: selected || (_revealed && isCorrect) ? 1.7 : 1)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: selected ? scheme.primary : scheme.surfaceContainerHighest, shape: BoxShape.circle),
              child: _isMulti
                  ? Icon(selected ? Icons.check_rounded : Icons.add_rounded, color: selected ? scheme.onPrimary : scheme.onSurfaceVariant, size: 20)
                  : Text(_letter(idx), style: TextStyle(fontWeight: FontWeight.w900, color: selected ? scheme.onPrimary : scheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(opt, style: const TextStyle(fontSize: 16, height: 1.45, fontWeight: FontWeight.w600))),
            if (trailing != null) Icon(trailing, color: border),
          ]),
        ),
      ),
    );
  }

  static const _letters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و', 'ز', 'ح', 'ط', 'ي', 'ك', 'ل', 'م', 'ن'];
  static String _letter(int i) => i < _letters.length ? _letters[i] : '؟';
}

class _FeedbackCard extends StatelessWidget {
  final bool correct;
  final String text;
  final String? explanation;
  const _FeedbackCard({required this.correct, required this.text, required this.explanation});

  @override
  Widget build(BuildContext context) {
    final color = correct ? Colors.green : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(.07), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(.22))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(correct ? Icons.check_circle_rounded : Icons.info_rounded, color: color), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)))]),
        if (explanation != null && explanation!.isNotEmpty) ...[
          const Divider(height: 24),
          const Text('الشرح', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(explanation!, style: const TextStyle(height: 1.6)),
        ],
      ]),
    );
  }
}
