import 'package:flutter/material.dart';
import 'modern_theme.dart';
import '../data/db.dart';
import 'exam_cat.dart';

class _Loading extends StatelessWidget {
  final Future<List<Map<String, Object?>>> future;
  final Widget Function(List<Map<String, Object?>>) builder;
  const _Loading({required this.future, required this.builder});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final rows = snap.data ?? const [];
          if (rows.isEmpty) return const _EmptyState();
          return builder(rows);
        },
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: 52, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        const Text('لا توجد بيانات بعد', style: TextStyle(fontWeight: FontWeight.w700)),
      ]));
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});
  @override
  Widget build(BuildContext context) => _CatalogScaffold(
        title: 'التصنيفات',
        subtitle: 'اختر مجالاً لبدء الاختبار',
        child: _Loading(
          future: AppDatabase.categories(),
          builder: (rows) => GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.05),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final c = rows[i];
              final name = c['name'] as String? ?? '';
              return _GridCard(
                emoji: c['emoji'] as String? ?? '📖',
                title: name,
                index: i + 1,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubcategoriesScreen(categoryId: c['id'] as int, title: name))),
              );
            },
          ),
        ),
      );
}

class SubcategoriesScreen extends StatelessWidget {
  final int categoryId;
  final String title;
  const SubcategoriesScreen({super.key, required this.categoryId, required this.title});
  @override
  Widget build(BuildContext context) => _CatalogScaffold(
        title: title,
        subtitle: 'اختر فرعاً للمتابعة',
        child: _Loading(
          future: AppDatabase.subcategories(categoryId),
          builder: (rows) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final s = rows[i];
              final name = s['name'] as String? ?? '';
              return _ListCard(
                emoji: s['emoji'] as String? ?? '📚',
                title: name,
                subtitle: 'عرض الموضوعات',
                index: i + 1,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopicsScreen(subcategoryId: s['id'] as int, title: name))),
              );
            },
          ),
        ),
      );
}

class TopicsScreen extends StatelessWidget {
  final int subcategoryId;
  final String title;
  const TopicsScreen({super.key, required this.subcategoryId, required this.title});
  @override
  Widget build(BuildContext context) => _CatalogScaffold(
        title: title,
        subtitle: 'اختر اختباراً من القائمة',
        child: _Loading(
          future: AppDatabase.topicsOfSubcategory(subcategoryId),
          builder: (rows) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final t = rows[i];
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
            },
          ),
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
