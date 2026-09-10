import 'package:flutter/material.dart';
import '../data/db.dart';
import '../data/exam_catalog.dart';
import '../data/exam_repository.dart';
import '../data/sqlite_exam_repository.dart';
import 'exam_cat.dart';

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: 52, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        const Text('لا توجد بيانات بعد', style: TextStyle(fontWeight: FontWeight.w700)),
      ]));
}

class ExamCatalogScreen extends StatefulWidget {
  const ExamCatalogScreen({super.key});

  @override
  State<ExamCatalogScreen> createState() => _ExamCatalogScreenState();
}

class _ExamCatalogScreenState extends State<ExamCatalogScreen> {
  late Future<List<ExamCatalogEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ExamCatalogEntry>> _load() async {
    final repo = await ExamRepository.instance;
    if (repo is ExamCatalogRepository) {
      return (repo as ExamCatalogRepository).activeExamCatalog();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) => _CatalogScaffold(
        title: 'الاختبارات',
        subtitle: 'اختبارات متاحة من مستودع المحتوى',
        child: FutureBuilder<List<ExamCatalogEntry>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = snap.data ?? const [];
            if (entries.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const _EmptyState(),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                    ),
                    child: const Text('استعراض التصنيفات المحلية'),
                  ),
                ]),
              );
            }
            final groups = <String, List<ExamCatalogEntry>>{};
            for (final entry in entries) {
              groups.putIfAbsent(entry.category, () => []).add(entry);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                for (final group in groups.entries) ...[
                  _SectionLabel(title: _categoryName(group.key)),
                  const SizedBox(height: 10),
                  ...group.value.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RemoteExamCard(entry: entry, onTap: () => _start(entry)),
                      )),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      );

  String _categoryName(String value) => switch (value) {
        'quran' => 'القرآن',
        'tajweed' => 'التجويد',
        _ => value,
      };

  Future<void> _start(ExamCatalogEntry entry) async {
    _startRemoteExam(context, entry);
  }
}

/// يفتح اختباراً بعيداً عبر [ExamCatScreen] بمسار `examId` فقط —
/// دون أي sentinel لـ `topicId`.
void _startRemoteExam(BuildContext context, ExamCatalogEntry entry) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ExamCatScreen(
        topicId: null,
        examId: entry.id,
        label: entry.title,
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
      );
}

class _RemoteExamCard extends StatelessWidget {
  const _RemoteExamCard({required this.entry, required this.onTap});
  final ExamCatalogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant.withOpacity(.7)),
          ),
          child: Row(children: [
            Container(
              width: 49,
              height: 49,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.quiz_outlined, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              if (entry.description != null) ...[
                const SizedBox(height: 4),
                Text(entry.description!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 7),
              Text('${entry.questionCount} سؤالاً', style: Theme.of(context).textTheme.labelSmall),
            ])),
            Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: scheme.primary),
          ]),
        ),
      ),
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<({List<Map<String, Object?>> local, List<RemoteCategoryNode> remote})>
      _load() async {
    final local = await AppDatabase.categories();
    var remote = const <RemoteCategoryNode>[];
    final repo = await ExamRepository.instance;
    if (repo is SQLiteExamRepository) {
      remote = await repo.remoteCategoryTree();
    }
    return (local: local, remote: remote);
  }

  @override
  Widget build(BuildContext context) => _CatalogScaffold(
        title: 'التصنيفات',
        subtitle: 'اختر مجالاً لبدء الاختبار',
        child: FutureBuilder(
          future: _load(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data;
            if (data == null) return const _EmptyState();
            final local = data.local;
            final remote = data.remote;
            if (local.isEmpty && remote.isEmpty) return const _EmptyState();
            final total = local.length + remote.length;
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.05),
              itemCount: total,
              itemBuilder: (context, i) {
                if (i < local.length) {
                  final c = local[i];
                  final name = c['name'] as String? ?? '';
                  return _GridCard(
                    emoji: c['emoji'] as String? ?? '📖',
                    title: name,
                    index: i + 1,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubcategoriesScreen(categoryId: c['id'] as int, title: name))),
                  );
                }
                final node = remote[i - local.length];
                return _GridCard(
                  emoji: node.emoji ?? '🛰️',
                  title: node.name,
                  index: i + 1,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RemoteBranchScreen(
                        categoryReference: node.reference,
                        title: node.name,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class SubcategoriesScreen extends StatelessWidget {
  final int categoryId;
  final String title;
  const SubcategoriesScreen({super.key, required this.categoryId, required this.title});

  Future<
      ({
        List<Map<String, Object?>> local,
        List<RemoteSubcategoryNode> subs,
        List<ExamCatalogEntry> direct,
      })> _load() async {
    final local = await AppDatabase.subcategories(categoryId);
    var subs = const <RemoteSubcategoryNode>[];
    var direct = const <ExamCatalogEntry>[];
    final repo = await ExamRepository.instance;
    if (repo is SQLiteExamRepository) {
      final ref = 'local:c:$categoryId';
      subs = await repo.remoteSubcategoriesFor(ref);
      direct = await repo.remoteExamsForCategory(ref);
    }
    return (local: local, subs: subs, direct: direct);
  }

  @override
  Widget build(BuildContext context) => _CatalogScaffold(
        title: title,
        subtitle: 'اختر فرعاً للمتابعة',
        child: FutureBuilder(
          future: _load(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data;
            final local = data?.local ?? const <Map<String, Object?>>[];
            final subs = data?.subs ?? const <RemoteSubcategoryNode>[];
            final direct = data?.direct ?? const <ExamCatalogEntry>[];
            if (local.isEmpty && subs.isEmpty && direct.isEmpty) {
              return const _EmptyState();
            }
            final total = local.length + subs.length + direct.length;
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              itemCount: total,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i < local.length) {
                  final s = local[i];
                  final name = s['name'] as String? ?? '';
                  return _ListCard(
                    emoji: s['emoji'] as String? ?? '📚',
                    title: name,
                    subtitle: 'عرض الموضوعات',
                    index: i + 1,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopicsScreen(subcategoryId: s['id'] as int, title: name))),
                  );
                }
                if (i < local.length + subs.length) {
                  final r = subs[i - local.length];
                  return _ListCard(
                    emoji: r.emoji ?? '📚',
                    title: r.name,
                    subtitle: '${r.examIds.length} اختباراً',
                    index: i + 1,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RemoteBranchScreen(
                          title: r.name,
                          subcategoryReference: r.reference,
                        ),
                      ),
                    ),
                  );
                }
                final entry = direct[i - local.length - subs.length];
                return _RemoteExamCard(
                  entry: entry,
                  onTap: () => _startRemoteExam(context, entry),
                );
              },
            );
          },
        ),
      );
}

class TopicsScreen extends StatelessWidget {
  final int subcategoryId;
  final String title;
  const TopicsScreen({super.key, required this.subcategoryId, required this.title});

  Future<({List<Map<String, Object?>> local, List<ExamCatalogEntry> direct})>
      _load() async {
    final local = await AppDatabase.topicsOfSubcategory(subcategoryId);
    var direct = const <ExamCatalogEntry>[];
    final repo = await ExamRepository.instance;
    if (repo is SQLiteExamRepository) {
      direct = await repo.remoteExamsForSubcategory('local:sc:$subcategoryId');
    }
    return (local: local, direct: direct);
  }

  @override
  Widget build(BuildContext context) => _CatalogScaffold(
        title: title,
        subtitle: 'اختر اختباراً من القائمة',
        child: FutureBuilder(
          future: _load(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data;
            final local = data?.local ?? const <Map<String, Object?>>[];
            final direct = data?.direct ?? const <ExamCatalogEntry>[];
            if (local.isEmpty && direct.isEmpty) return const _EmptyState();
            final total = local.length + direct.length;
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              itemCount: total,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i < local.length) {
                  final t = local[i];
                  final name = t['name'] as String? ?? '';
                  final desc = t['description'] as String?;
                  final count = (t['qcount'] as int?) ?? 0;
                  final topicId = t['id'] as int;
                  return _TopicCard(
                    title: name,
                    description: desc,
                    count: count,
                    index: i + 1,
                    onTap: () async {
                      if (count == 0) return;
                      final label = await AppDatabase.topicName(topicId);
                      if (!context.mounted) return;
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ExamCatScreen(topicId: topicId, label: label ?? name)));
                    },
                  );
                }
                final entry = direct[i - local.length];
                return _RemoteExamCard(
                  entry: entry,
                  onTap: () => _startRemoteExam(context, entry),
                );
              },
            );
          },
        ),
      );
}

/// تصفح فرع بعيد (category أو subcategory): الفروع الفرعية والاختبارات
/// المباشرة. لا يُمرَّر أي `topicId` للاختبارات البعيدة (لا sentinel).
class RemoteBranchScreen extends StatefulWidget {
  final String title;

  /// مرجع category للتصفح (يعرض فروعه الفرعية واختباراته المباشرة).
  final String? categoryReference;

  /// مرجع subcategory للعرض المباشر لاختباراتها.
  final String? subcategoryReference;
  const RemoteBranchScreen({super.key, required this.title, this.categoryReference, this.subcategoryReference});

  @override
  State<RemoteBranchScreen> createState() => _RemoteBranchScreenState();
}

class _RemoteBranchScreenState extends State<RemoteBranchScreen> {
  late Future<({List<RemoteSubcategoryNode> subs, List<ExamCatalogEntry> exams})> _future;

  Future<({List<RemoteSubcategoryNode> subs, List<ExamCatalogEntry> exams})>
      _load() async {
    final repo = await ExamRepository.instance;
    if (repo is! SQLiteExamRepository) {
      return (subs: const <RemoteSubcategoryNode>[], exams: const <ExamCatalogEntry>[]);
    }
    var subs = const <RemoteSubcategoryNode>[];
    var exams = const <ExamCatalogEntry>[];
    if (widget.subcategoryReference != null) {
      exams = await repo.remoteExamsForSubcategory(widget.subcategoryReference!);
    } else if (widget.categoryReference != null) {
      subs = await repo.remoteSubcategoriesFor(widget.categoryReference!);
      exams = await repo.remoteExamsForCategory(widget.categoryReference!);
    }
    return (subs: subs, exams: exams);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) => _CatalogScaffold(
        title: widget.title,
        subtitle: 'اختر اختباراً من القائمة',
        child: FutureBuilder(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data;
            final subs = data?.subs ?? const <RemoteSubcategoryNode>[];
            final exams = data?.exams ?? const <ExamCatalogEntry>[];
            if (subs.isEmpty && exams.isEmpty) return const _EmptyState();
            final total = subs.length + exams.length;
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              itemCount: total,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i < subs.length) {
                  final s = subs[i];
                  return _ListCard(
                    emoji: s.emoji ?? '📚',
                    title: s.name,
                    subtitle: '${s.examIds.length} اختباراً',
                    index: i + 1,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RemoteBranchScreen(
                          title: s.name,
                          subcategoryReference: s.reference,
                        ),
                      ),
                    ),
                  );
                }
                final entry = exams[i - subs.length];
                return _RemoteExamCard(
                  entry: entry,
                  onTap: () => _startRemoteExam(context, entry),
                );
              },
            );
          },
        ),
      );
}

class _CatalogScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _CatalogScaffold({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 15), child: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium)),
            Expanded(child: child),
          ]),
        ),
      );
}

class _GridCard extends StatelessWidget {
  final String emoji;
  final String title;
  final int index;
  final VoidCallback onTap;
  const _GridCard({required this.emoji, required this.title, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: scheme.outlineVariant.withOpacity(.7))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(width: 51, height: 51, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26)))),
              const Spacer(),
              Text('$index', style: TextStyle(color: scheme.outline, fontWeight: FontWeight.w800)),
            ]),
            Row(children: [Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))), const SizedBox(width: 5), Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: scheme.primary)]),
          ]),
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final int index;
  final VoidCallback onTap;
  const _ListCard({required this.emoji, required this.title, required this.subtitle, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: scheme.outlineVariant.withOpacity(.7))),
          child: Row(children: [
            Container(width: 49, height: 49, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(15)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22)))),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)), child: Text('$index', style: const TextStyle(fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: scheme.outline),
          ]),
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final String title;
  final String? description;
  final int count;
  final int index;
  final VoidCallback onTap;
  const _TopicCard({required this.title, required this.description, required this.count, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = count > 0;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: scheme.outlineVariant.withOpacity(.7))),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: enabled ? scheme.primaryContainer : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(15)), child: Icon(Icons.quiz_outlined, color: enabled ? scheme.onPrimaryContainer : scheme.outline)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: enabled ? null : scheme.outline)),
              if (description != null && description!.isNotEmpty) ...[const SizedBox(height: 4), Text(description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)],
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)), child: Text(enabled ? '$count سؤالاً' : 'لا توجد أسئلة', style: Theme.of(context).textTheme.labelSmall)),
            ])),
            Column(children: [Text('$index', style: TextStyle(color: scheme.outline, fontWeight: FontWeight.w800)), const SizedBox(height: 7), Icon(enabled ? Icons.arrow_back_ios_new_rounded : Icons.lock_outline_rounded, size: 15, color: enabled ? scheme.primary : scheme.outline)]),
          ]),
        ),
      ),
    );
  }
}
