import 'package:flutter/material.dart';
import '../data/quran_gen.dart';
import 'exam.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختبارات قالون')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book, size: 32),
              title: const Text('اختبار الآيات'),
              subtitle: const Text('ما السورة التي تتبعها هذه الآية؟'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExamScreen(quarterId: null)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...quarters.map((q) => Card(
                child: ListTile(
                  leading: Text(q.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text('اختبار ${q.name}'),
                  subtitle: const Text('آيات من هذا الربع فقط'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ExamScreen(quarterId: q.id)),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
