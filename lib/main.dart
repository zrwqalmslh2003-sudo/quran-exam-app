import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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