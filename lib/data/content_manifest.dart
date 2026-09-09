/// نموذج المانفيست (فهرس المحتوى) — تطبيق عقد `docs/content-schema/manifest.schema.json`.
///
/// المانفيست هو أول ملف يُقرأ (محلياً مجمّعاً حالياً، ولاحقاً من GitHub).
/// أية مخالفة للعقد ترفض بإلقاء [FormatException] أثناء التحليل.
library;

/// [ContentManifest.exams] — وصف اختبار واحد.
class ManifestExam {
  const ManifestExam({
    required this.id,
    required this.version,
    required this.title,
    required this.file,
    this.category,
    this.questionCount,
    this.updatedAt,
  });

  factory ManifestExam.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final version = json['version'];
    final title = json['title'];
    final file = json['file'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('manifest exam: id مطلوب وغير فارغ');
    }
    if (version is! int || version < 1) {
      throw const FormatException('manifest exam: version عدد ≥ 1');
    }
    if (title is! String || title.isEmpty) {
      throw const FormatException('manifest exam: title مطلوب وغير فارغ');
    }
    if (file is! String ||
        !RegExp(r'^[A-Za-z0-9_./-]+\.json$').hasMatch(file)) {
      throw const FormatException(
          'manifest exam: file مسار JSON صالح مثل exams/quran_qalon.json');
    }
    final category = json['category'];
    if (category != null && category is! String) {
      throw const FormatException('manifest exam: category يجب أن يكون نصاً');
    }
    final updatedAt = json['updatedAt'];
    if (updatedAt != null && updatedAt is! String) {
      throw const FormatException('manifest exam: updatedAt يجب أن يكون نصاً');
    }
    final count = json['questionCount'];
    if (count != null && count is! int) {
      throw const FormatException('manifest exam: questionCount يجب أن يكون عدداً');
    }
    return ManifestExam(
      id: id,
      version: version,
      title: title,
      file: file,
      category: category as String?,
      questionCount: count is int && count >= 0 ? count : null,
      updatedAt: updatedAt as String?,
    );
  }

  final String id;

  /// أحدث نسخة منشورة من الاختبار، تُقارن بالنسخة المحلية المخزنة محلياً.
  final int version;

  final String title;

  /// مسار ملف الاختبار داخل مستودع المحتوى (مثال: `exams/quran_qalon.json`).
  final String file;

  final String? category;

  /// عدد الأسئلة المعروف (اختياري، يُعرض قبل التحميل).
  final int? questionCount;

  final String? updatedAt;

  /// هل النسخة [remote] أحدث من النسخة [local]؟
  bool isNewerThan(int local) => version > local;

  Map<String, Object?> toJson() => {
        'id': id,
        'version': version,
        'title': title,
        'file': file,
        if (category != null) 'category': category,
        if (questionCount != null) 'questionCount': questionCount,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };
}

/// فهرس التحديث المركزي — [ContentManifest.schemaVersion] هو إصدار العقد.
class ContentManifest {
  const ContentManifest({
    required this.schemaVersion,
    required this.contentVersion,
    required this.exams,
    this.updatedAt,
  });

  /// يحلل المانفيست ويرفض أي مخالفة للعقد (schemaVersion 1).
  factory ContentManifest.fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('manifest: الجذر يجب أن يكون كائناً JSON');
    }
    final schema = raw['schemaVersion'];
    final contentVersion = raw['contentVersion'];
    if (schema is! int || schema != 1) {
      throw const FormatException('manifest: schemaVersion غير مدعوم (العدد 1 فقط)');
    }
    if (contentVersion is! int || contentVersion < 1) {
      throw const FormatException('manifest: contentVersion عدد ≥ 1');
    }
    final items = raw['exams'];
    if (items is! List || items.isEmpty) {
      throw const FormatException('manifest: exams مصفوفة غير فارغة');
    }
    final exams = <ManifestExam>[];
    final seen = <String>{};
    for (final item in items) {
      if (item is! Map) {
        throw const FormatException('manifest: كل عنصر في exams يجب أن يكون كائناً');
      }
      final exam = ManifestExam.fromJson(item.cast<String, Object?>());
      if (!seen.add(exam.id)) {
        throw FormatException('manifest: معرف مكرر "${exam.id}"');
      }
      exams.add(exam);
    }
    final updatedAt = raw['updatedAt'];
    if (updatedAt != null && updatedAt is! String) {
      throw const FormatException('manifest: updatedAt يجب أن يكون نصاً');
    }
    return ContentManifest(
      schemaVersion: schema,
      contentVersion: contentVersion,
      exams: exams,
      updatedAt: updatedAt as String?,
    );
  }

  /// إصدار عقد المحتوى (ثابت على 1 حتى كسر البنية).
  final int schemaVersion;

  /// إصدار الفهرس نفسه — يُرفع كلما تغيّر المانفيست.
  final int contentVersion;

  final List<ManifestExam> exams;

  final String? updatedAt;

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'contentVersion': contentVersion,
        if (updatedAt != null) 'updatedAt': updatedAt,
        'exams': exams.map((e) => e.toJson()).toList(),
      };
}
