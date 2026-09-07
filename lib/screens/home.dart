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
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(child: _Header(scheme: scheme)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _HeroCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(child: _ActionCard(
                      icon: Icons.category_rounded,
                      title: 'التصنيفات',
                      subtitle: 'اختبارات منظمة',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _ActionCard(
                      icon: Icons.shuffle_rounded,
                      title: 'عشوائي',
                      subtitle: 'اختبار سريع',
                      accent: scheme.secondary,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RandomSetupScreen())),
                    )),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
              sliver: SliverToBoxAdapter(child: _SectionTitle(title: 'اختبارات الآيات', subtitle: 'اختبر معرفتك بمواضع السور')),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _QuranCard(
                  title: 'القرآن كاملاً',
                  subtitle: 'أسئلة متنوعة من سور القرآن الكريم',
                  icon: Icons.menu_book_rounded,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamScreen(quarterId: null))),
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
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _QuranCard(
                        title: q.name,
                        subtitle: 'اختبار من هذا الربع فقط',
                        icon: Icons.auto_stories_rounded,
                        emoji: q.emoji,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamScreen(quarterId: q.id))),
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
    );
  }
}

class _Header extends StatelessWidget {
  final ColorScheme scheme;
  const _Header({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(17)),
          child: Icon(Icons.auto_stories_rounded, color: scheme.onPrimaryContainer, size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مرحباً بك', style: TextStyle(fontSize: 14)),
              SizedBox(height: 2),
              Text('اختبارات قالون', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Icon(Icons.menu_book_outlined, color: scheme.primary),
      ],
    );
  }
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
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ابدأ رحلتك', style: TextStyle(color: scheme.onPrimary.withOpacity(.78), fontSize: 14)),
                    const SizedBox(height: 5),
                    Text('اختبر معلوماتك في القرآن وعلومه', style: TextStyle(color: scheme.onPrimary, fontSize: 21, fontWeight: FontWeight.w800, height: 1.35)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                      decoration: BoxDecoration(color: scheme.onPrimary.withOpacity(.14), borderRadius: BorderRadius.circular(14)),
                      child: Text('عرض التصنيفات  ←', style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.menu_book_rounded, size: 72, color: scheme.onPrimary.withOpacity(.22)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap, this.accent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(backgroundColor: color.withOpacity(.12), foregroundColor: color, child: Icon(icon)),
            const SizedBox(height: 13),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class _QuranCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? emoji;
  final VoidCallback onTap;
  const _QuranCard({required this.title, required this.subtitle, required this.icon, required this.onTap, this.emoji});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(15)),
              child: emoji != null ? Center(child: Text(emoji!, style: const TextStyle(fontSize: 23))) : Icon(icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ])),
            Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: scheme.outline),
          ]),
        ),
      ),
    );
  }
}
