import 'package:flutter/material.dart';
import '../data/db.dart';
import 'exam_cat.dart';

class _Loading extends StatelessWidget {
  final Future<List<Map<String, Object?>>> future;
  final Widget Function(List<Map<String, Object?>>) builder;
  const _Loading({required this.future, required this.builder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return const Center(child: Text('لا توجد بيانات بعد'));
        }
        return builder(rows);
      },
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختبارات التصنيفات')),
      body: _Loading(
        future: AppDatabase.categories(),
        builder: (rows) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = rows[i];
            final name = c['name'] as String? ?? '';
            final emoji = c['emoji'] as String? ?? '📖';
            return Card(
              child: ListTile(
                leading: Text(emoji, style: const TextStyle(fontSize: 26)),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubcategoriesScreen(
                        categoryId: c['id'] as int, title: name),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SubcategoriesScreen extends StatelessWidget {
  final int categoryId;
  final String title;
  const SubcategoriesScreen(
      {super.key, required this.categoryId, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _Loading(
        future: AppDatabase.subcategories(categoryId),
        builder: (rows) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final s = rows[i];
            final name = s['name'] as String? ?? '';
            final emoji = s['emoji'] as String? ?? '📚';
            return Card(
              child: ListTile(
                leading: Text(emoji, style: const TextStyle(fontSize: 26)),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TopicsScreen(
                        subcategoryId: s['id'] as int, title: name),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class TopicsScreen extends StatelessWidget {
  final int subcategoryId;
  final String title;
  const TopicsScreen(
      {super.key, required this.subcategoryId, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _Loading(
        future: AppDatabase.topicsOfSubcategory(subcategoryId),
        builder: (rows) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final t = rows[i];
            final name = t['name'] as String? ?? '';
            final desc = t['description'] as String?;
            final count = (t['qcount'] as int?) ?? 0;
            final topicId = t['id'] as int;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Text('📄'),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: desc != null && desc.isNotEmpty
                    ? Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: count > 0
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$count سؤالاً',
                              style: Theme.of(context).textTheme.bodySmall),
                          const Icon(Icons.play_circle_fill, color: Colors.teal),
                        ],
                      )
                    : const Text('فارغ'),
                onTap: () async {
                  final label = await AppDatabase.topicName(topicId);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExamCatScreen(
                        topicId: topicId,
                        label: label ?? name,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}