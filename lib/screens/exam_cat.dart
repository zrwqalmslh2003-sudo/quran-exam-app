import 'package:flutter/material.dart';
import '../data/db.dart';
import '../models/question.dart';
import 'result.dart';

/// محرك اختبار موحّد يدعم أنواع poll/quiz/true_false،
/// وأسئلة متعددة الإجابات، مع تغذية راجعة وشرح فوريين.
class ExamCatScreen extends StatefulWidget {
  final int topicId;
  final String label;
  final List<Question>? questions;

  const ExamCatScreen(
      {super.key,
      required this.topicId,
      required this.label,
      this.questions});

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
    final q = widget.questions;
    _future = q != null ? Future.value(q) : _load();
  }

  Future<List<Question>> _load() async {
    final list = await AppDatabase.questionsForTopic(widget.topicId);
    _questions = list;
    return list;
  }

  int get _totalPoints => _questions.fold<int>(0, (s, q) => s + q.points);

  Question get _question => _questions[_index];
  bool get _isMulti => _question.allowsMultiple;

  void _reset() {
    setState(() {
      _index = 0;
      _score = 0;
      _selection.clear();
      _revealed = false;
      _answeredCorrectly = false;
    });
  }

  void _toggle(int optionIndex) {
    if (_revealed) return;
    setState(() {
      if (_isMulti) {
        if (_selection.contains(optionIndex)) {
          _selection.remove(optionIndex);
        } else {
          _selection.add(optionIndex);
        }
      } else {
        _selection
          ..clear()
          ..add(optionIndex);
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
    if (_index + 1 >= _questions.length) {
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
  Widget build(BuildContext context) {
    return FutureBuilder<List<Question>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.hasData) {
          _questions = snap.data!;
        }
        return _scaffold(
          snap.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : _questions.isEmpty
                  ? const Center(child: Text('لا توجد أسئلة في هذا الاختبار'))
                  : _body(),
        );
      },
    );
  }

  bool get _last => _index + 1 >= _questions.length;

  Widget _scaffold(Widget body) {
    final progress = _questions.isEmpty
        ? 0.0
        : (_index + (_revealed ? 1 : 0)) / _questions.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
                child: Text('$_score/$_totalPoints',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(value: progress),
        ),
      ),
      body: body,
    );
  }

  String _statusText() {
    final q = _question;
    final correct = _answerLabel(q);
    if (_answeredCorrectly) return 'صحيح! ✅ الإجابة: $correct';
    return 'خطأ ❌ الإجابة الصحيحة: $correct';
  }

  String _answerLabel(Question q) {
    if (q.allowsMultiple && q.correctOptionIds.isNotEmpty) {
      return q.correctOptionIds.map((i) => q.options[i]).join('، ');
    }
    final i = q.correctOptionId;
    if (i != null && i >= 0 && i < q.options.length) return q.options[i];
    return '—';
  }

  Widget _body() {
    final q = _question;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('السؤال ${_index + 1} من ${_questions.length}',
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(q.text,
                style: const TextStyle(fontSize: 18, height: 1.7)),
          ),
        ),
        const SizedBox(height: 12),
        ...q.options.asMap().entries.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: _buildOption(e.key, e.value, q),
          );
        }),
        const SizedBox(height: 12),
        if (_isMulti && !_revealed)
          FilledButton(
            onPressed: _selection.isEmpty ? null : _confirm,
            child: const Text('تأكيد الإجابة'),
          ),
        if (_revealed) ...[
          Card(
            color: _answeredCorrectly
                ? Colors.green.withOpacity(0.12)
                : Colors.red.withOpacity(0.12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusText(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                    const Divider(),
                    Text('📘 ${q.explanation}',
                        style: const TextStyle(height: 1.6, fontSize: 14)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _next,
            icon: Icon(_last ? Icons.flag : Icons.navigate_next),
            label: Text(_last ? 'إنهاء الاختبار' : 'السؤال التالي'),
          ),
        ],
      ],
    );
  }

  Widget _buildOption(int idx, String opt, Question q) {
    final selected = _selection.contains(idx);
    Color? borderColor;
    Color? fill;
    Widget? trailing;

    if (_revealed) {
      final isCorrectOption = q.allowsMultiple
          ? q.correctOptionIds.contains(idx)
          : q.correctOptionId == idx;
      if (isCorrectOption) {
        borderColor = Colors.green;
        fill = Colors.green.withOpacity(0.08);
        trailing = const Icon(Icons.check_circle, color: Colors.green);
      } else if (selected) {
        borderColor = Colors.red;
        fill = Colors.red.withOpacity(0.08);
        trailing = const Icon(Icons.cancel, color: Colors.red);
      }
    }

    return Card(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderColor != null
            ? BorderSide(color: borderColor, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: _isMulti
            ? Icon(selected ? Icons.check_box : Icons.check_box_outline_blank)
            : CircleAvatar(
                radius: 14,
                backgroundColor: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  _letter(idx),
                  style: TextStyle(
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
        title: Text(opt, style: const TextStyle(fontSize: 16, height: 1.5)),
        trailing: trailing,
        onTap: _revealed ? null : () => _toggle(idx),
      ),
    );
  }

  static const List<String> _letters =
      ['أ', 'ب', 'ج', 'د', 'هـ', 'و', 'ز', 'ح', 'ط', 'ي', 'ك', 'ل', 'م', 'ن'];

  static String _letter(int i) =>
      i >= 0 && i < _letters.length ? _letters[i] : '؟';
}