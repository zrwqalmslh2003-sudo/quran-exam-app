import 'dart:convert';

import '../models/question.dart';

/// وصف اختبار قابل للاكتشاف من المحتوى النشط محليًا.
class ExamCatalogEntry {
  const ExamCatalogEntry({
    required this.id,
    required this.version,
    required this.title,
    required this.category,
    required this.questionCount,
    this.description,
  });

  final String id;
  final int version;
  final String title;
  final String category;
  final int questionCount;
  final String? description;

  factory ExamCatalogEntry.fromPayload(String payload) {
    final raw = jsonDecode(payload);
    if (raw is! Map<String, Object?>) {
      throw const FormatException('catalog payload يجب أن يكون كائناً JSON');
    }
    final id = raw['id'];
    final version = raw['version'];
    final title = raw['title'];
    final category = raw['category'];
    final description = raw['description'];
    final questions = raw['questions'];
    if (id is! String || id.isEmpty ||
        version is! int || version < 1 ||
        title is! String || title.isEmpty ||
        category is! String || category.isEmpty ||
        questions is! List || questions.isEmpty) {
      throw const FormatException('catalog payload حقوله الأساسية غير صالحة');
    }
    return ExamCatalogEntry(
      id: id,
      version: version,
      title: title,
      category: category,
      questionCount: questions.length,
      description: description is String && description.isNotEmpty ? description : null,
    );
  }
}

/// واجهة اختيارية لمستودعات تدعم الكتالوج الديناميكي.
abstract interface class ExamCatalogRepository {
  Future<List<ExamCatalogEntry>> activeExamCatalog();
  Future<List<Question>> questionsForExam(String examId);
}
