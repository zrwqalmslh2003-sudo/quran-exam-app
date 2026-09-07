import 'package:flutter/material.dart';
import '../data/db.dart';
import '../models/question.dart';
import 'result.dart';

class ExamCatScreen extends StatefulWidget {
  final int topicId;
  final String label;
  final List<Question>? questions;
  const ExamCatScreen({super.key, required this.topicId, required this.label, this.questions});
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
    final list = await AppDatabase.questionsForTopic(widget.topicId);
    _questions = list;
    return list;
  }

  int get _totalPoints => _questions.fold<int>(0, (s, q) => s + q.points);
  Question get _question => _questions[_index];
  bool get _isMulti => _question.allowsMultiple;
  bool get _last => _index + 1 >= _questions.length;

  void _reset() => setState(() { _index = 0; _score = 0; _selection.clear(); _revealed = false; _answeredCorrectly = false; });

  void _toggle(int i) {
    if (_revealed) return;
    setState(() {
      if (_isMulti) { _selection.contains(i) ? _selection.remove(i) : _selection.add(i); }
      else { _selection..clear()..add(i); }
    });
  }

  void _confirm() {
    if (_revealed || _selection.isEmpty) return;
    final correct = _question.isCorrectFor(_selection);
    setState(() { _answeredCorrectly = correct; _revealed = true; if (correct) _score += _question.points; });
  }

  void _next() {
    if (_last) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(score: _score, totalPoints: _totalPoints, questionCount: _questions.length, label: widget.label, onRetry: () { Navigator.pop(context); _reset(); })));
      return;
    }
    setState(() { _index++; _selection.clear(); _revealed = false; _answeredCorrectly = false; });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Question>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.hasData) _questions = snap.data!;
        final body = snap.connectionState != ConnectionState.done
            ? const Center(child: CircularProgressIndicator())
            : _questions.isEmpty ? const Center(child: Text('لا توجد أسئلة في هذا الاختبار')) : _body();
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [Padding(padding: const EdgeInsetsDirectional.only(end: 18), child: Center(child: Text('$_score / $_totalPoints', style: const TextStyle(fontWeight: FontWeight.w800))))],
            bottom: PreferredSize(preferredSize: const Size.fromHeight(5), child: LinearProgressIndicator(value: _questions.isEmpty ? 0 : (_index + (_revealed ? 1 : 0)) / _questions.length)),
          ),
          body: body,
        );
      },
    );
  }

  Widget _body() {
    final q = _question;
    final scheme = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
      Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(10)), child: Text('السؤال ${_index + 1}', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800))),
        const Spacer(),
        Text('من ${_questions.length}', style: Theme.of(context).textTheme.bodySmall),
      ]),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Icon(Icons.help_outline_rounded, color: scheme.primary, size: 30),
        const SizedBox(height: 12),
        Text(q.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, height: 1.75, fontWeight: FontWeight.w600)),
      ]))),
      if (_isMulti && !_revealed) Padding(padding: const EdgeInsets.only(top: 12), child: Text('يمكن اختيار أكثر من إجابة', style: Theme.of(context).textTheme.bodySmall)),
      const SizedBox(height: 10),
      ...q.options.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildOption(e.key, e.value, q))),
      if (_isMulti && !_revealed) FilledButton.icon(onPressed: _selection.isEmpty ? null : _confirm, icon: const Icon(Icons.check_rounded), label: const Text('تأكيد الإجابة'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      if (_revealed) ...[
        const SizedBox(height: 4),
        _FeedbackCard(correct: _answeredCorrectly, text: _statusText(), explanation: q.explanation),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _next, icon: Icon(_last ? Icons.flag_rounded : Icons.arrow_back_rounded), label: Text(_last ? 'إنهاء الاختبار' : 'السؤال التالي'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      ],
    ]);
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
    Color? border;
    Color? fill;
    IconData? icon;
    if (_revealed && isCorrect) { border = Colors.green; fill = Colors.green.withOpacity(.08); icon = Icons.check_circle_rounded; }
    else if (_revealed && selected) { border = Colors.redAccent; fill = Colors.redAccent.withOpacity(.08); icon = Icons.cancel_rounded; }
    else if (selected) { border = scheme.primary; fill = scheme.primary.withOpacity(.08); }

    return Material(color: fill ?? scheme.surface, borderRadius: BorderRadius.circular(17), child: InkWell(
      borderRadius: BorderRadius.circular(17), onTap: _revealed ? null : () => _toggle(idx),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), border: Border.all(color: border ?? scheme.outlineVariant, width: selected || (_revealed && isCorrect) ? 1.6 : 1)), child: Row(children: [
        Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: selected ? scheme.primary : scheme.surfaceContainerHighest, shape: BoxShape.circle), child: _isMulti ? Icon(selected ? Icons.check_rounded : Icons.add_rounded, color: selected ? scheme.onPrimary : scheme.onSurfaceVariant, size: 20) : Text(_letter(idx), style: TextStyle(fontWeight: FontWeight.w800, color: selected ? scheme.onPrimary : scheme.onSurfaceVariant))),
        const SizedBox(width: 12),
        Expanded(child: Text(opt, style: const TextStyle(fontSize: 16, height: 1.45, fontWeight: FontWeight.w600))),
        if (icon != null) Icon(icon, color: border),
      ])),
    ));
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
  Widget build(BuildContext context) => Card(color: correct ? Colors.green.withOpacity(.09) : Colors.red.withOpacity(.08), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(correct ? Icons.check_circle_rounded : Icons.info_rounded, color: correct ? Colors.green : Colors.redAccent), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)))]),
        if (explanation != null && explanation!.isNotEmpty) ...[const Divider(height: 24), const Text('الشرح', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(explanation!, style: const TextStyle(height: 1.6))],
      ])));
}
