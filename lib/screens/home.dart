import 'package:flutter/material.dart';
import '../data/quran_gen.dart';
import 'catalog.dart';
import 'exam.dart';
import 'random_setup.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('اختبارات قالون')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _MainCard(
            icon: Icons.menu_book,
            iconBg: scheme.primaryContainer,
            iconColor: scheme.onPrimaryContainer,
            title: 'اختبارات التصنيفات',
            subtitle: 'أصول الرواية • الرسم • المتشابهات',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _MainCard(
            icon: Icons.shuffle,
            iconBg: scheme.tertiaryContainer,
            iconColor: scheme.onTertiaryContainer,
            title: 'الاختبار العشوائي',
            subtitle: 'حدّد عدد الأسئلة والنطاق',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RandomSetupScreen()),
            ),
          ),
          const SizedBox(height: 16),
          Text('اختبار الآيات',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _MainCard(
            icon: Icons.auto_stories,
            iconBg: scheme.secondaryContainer,
            iconColor: scheme.onSecondaryContainer,
            title: 'القرآن كاملاً',
            subtitle: 'آيات من كل القرآن',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ExamScreen(quarterId: null)),
            ),
          ),
          const SizedBox(height: 8),
          ...quarters.map((q) => _MainCard(
                icon: null,
                emoji: q.emoji,
                iconBg: scheme.surfaceContainerHighest,
                iconColor: scheme.onSurface,
                title: 'اختبار ${q.name}',
                subtitle: 'آيات من هذا الربع فقط',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ExamScreen(quarterId: q.id)),
                ),
              )),
        ],
      ),
    );
  }
}

class _MainCard extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MainCard({
    required this.icon,
    required this.emoji,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: emoji != null
              ? Center(
                  child: Text(emoji!, style: const TextStyle(fontSize: 24)))
              : Icon(icon, color: iconColor),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}