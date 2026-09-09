import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/modern_theme.dart';

void main() {
  runApp(const QuranExamApp());
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
      theme: buildModernTheme(),
      home: const HomeScreen(),
    );
  }
}