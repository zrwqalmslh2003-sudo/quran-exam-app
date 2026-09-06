import 'package:flutter/material.dart';
import 'screens/home.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}