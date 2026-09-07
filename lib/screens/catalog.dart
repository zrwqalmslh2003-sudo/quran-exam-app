import 'package:flutter/material.dart';
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
        const Text('لا توجد بيانات بعد'),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.08),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final c = rows[i];
              final name = c['name'] as String? ?? '';
              return _GridCard(
                emoji: c['emoji'] as String? ?? '📖',
                title: name,
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
                onTap: () async {
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 14), child: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(child: child),
        ]),
      );
}

class _GridCard extends StatelessWidget {
  final String emoji;
  final String title;
  final VoidCallback onTap;
  const _GridCard({required this.emoji, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 27)))),
        Row(children: [Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))), const Icon(Icons.arrow_back_ios_new_rounded, size: 14)]),
      ]))));
}

class _ListCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ListCard({required this.emoji, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), leading: CircleAvatar(radius: 25, backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Text(emoji, style: const TextStyle(fontSize: 23))), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 16), onTap: onTap));
}

class _TopicCard extends StatelessWidget {
  final String title;
  final String? description;
  final int count;
  final VoidCallback onTap;
  const _TopicCard({required this.title, required this.description, required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.quiz_outlined, color: scheme.onPrimaryContainer)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), if (description != null && description!.isNotEmpty) ...[const SizedBox(height: 4), Text(description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)], const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: Text(count > 0 ? '$count سؤالاً' : 'فارغ', style: Theme.of(context).textTheme.labelSmall))])),
      Icon(Icons.play_circle_outline_rounded, color: count > 0 ? scheme.primary : scheme.outline),
    ]))));
  }
}
