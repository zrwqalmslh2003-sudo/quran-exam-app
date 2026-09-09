import 'package:flutter/material.dart';
import 'modern_theme.dart';
import '../data/quran_gen.dart';
import 'catalog.dart';
import 'random_setup.dart';
import 'quran_setup.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme(data: buildModernTheme(), child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(child: _TopBar(scheme: scheme)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _HeroCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExamCatalogScreen()),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.category_rounded,
                          title: 'التصنيفات',
                          subtitle: 'اختبارات منظمة',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamCatalogScreen())),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.shuffle_rounded,
                          title: 'اختبار عشوائي',
                          subtitle: 'اختبر نفسك سريعاً',
                          accent: scheme.secondary,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RandomSetupScreen())),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 30, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'اختبارات القرآن',
                    subtitle: 'تعرّف على مواضع الآيات والسور',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: _QuranCard(
                    title: 'القرآن كاملاً',
                    subtitle: 'أسئلة متنوعة من سور القرآن الكريم',
                    icon: Icons.menu_book_rounded,
                    featured: true,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranSetupScreen())),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final q = quarters[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _QuranCard(
                          title: q.name,
                          subtitle: 'اختبار من هذا الربع فقط',
                          icon: Icons.auto_stories_rounded,
                          emoji: q.emoji,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuranSetupScreen(quarter: q))),
                        ),
                      );
                    },
                    childCount: quarters.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class _TopBar extends StatelessWidget {
  final ColorScheme scheme;
  const _TopBar({required this.scheme});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(Icons.auto_stories_rounded, color: scheme.onPrimaryContainer, size: 27),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً بك', style: TextStyle(fontSize: 13)),
                SizedBox(height: 2),
                Text('اختبارات قالون', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Icon(Icons.menu_book_outlined, color: scheme.primary, size: 25),
        ],
      );
}

class _HeroCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 23, 18, 22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('رحلتك مع القرآن', style: TextStyle(color: scheme.onPrimary.withOpacity(.75), fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    Text('اختبر معلوماتك في القرآن وعلومه', style: TextStyle(color: scheme.onPrimary, fontSize: 21, height: 1.4, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 17),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(color: scheme.onPrimary.withOpacity(.13), borderRadius: BorderRadius.circular(999)),
                      child: Text('ابدأ الآن  ←', style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.menu_book_rounded, size: 74, color: scheme.onPrimary.withOpacity(.18)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;
  const _QuickAction({required this.icon, required this.title, required this.subtitle, required this.onTap, this.accent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outlineVariant.withOpacity(.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(.10), shape: BoxShape.circle), child: Icon(icon, color: color)),
              const SizedBox(height: 13),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class _QuranCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? emoji;
  final bool featured;
  final VoidCallback onTap;
  const _QuranCard({required this.title, required this.subtitle, required this.icon, required this.onTap, this.emoji, this.featured = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(featured ? 24 : 20),
      child: InkWell(
        borderRadius: BorderRadius.circular(featured ? 24 : 20),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(featured ? 18 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(featured ? 24 : 20),
            border: Border.all(color: featured ? scheme.primary.withOpacity(.22) : scheme.outlineVariant.withOpacity(.7)),
          ),
          child: Row(
            children: [
              Container(
                width: featured ? 54 : 48,
                height: featured ? 54 : 48,
                decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
                child: emoji != null ? Center(child: Text(emoji!, style: const TextStyle(fontSize: 23))) : Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: featured ? 17 : 15)),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ])),
              Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
