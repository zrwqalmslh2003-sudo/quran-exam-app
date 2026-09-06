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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        fontFamilyFallback: const ['Noto Naskh Arabic'],
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
