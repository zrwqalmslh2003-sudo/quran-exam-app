import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/exam_repository.dart';
import 'data/github_content_source.dart';
import 'data/sqlite_exam_repository.dart';
import 'data/update_manager.dart';
import 'screens/home.dart';
import 'screens/modern_theme.dart';

void main() {
  runApp(const QuranExamApp());

  // فحص تحديث غير مانع (fire-and-forget): لا يحجب runApp ولا الشاشة الأولى.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final repo = await ExamRepository.instance;
    if (repo is SQLiteExamRepository) {
      UpdateManager.checkForUpdates(
        source: GithubContentSource(
          owner: 'zrwqalmslh2003-sudo',
          repo: 'quran-exam-app-content',
        ),
        repo: repo,
      );
    }
  });
}

class QuranExamApp extends StatelessWidget {
  const QuranExamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'اختبارات قالون',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildModernTheme(),
      home: const HomeScreen(),
    );
  }
}