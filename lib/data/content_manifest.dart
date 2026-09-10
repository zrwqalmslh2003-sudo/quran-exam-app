/// نموذج المانفيست (فهرس المحتوى) — تطبيق عقد `docs/content-schema/manifest.schema.json`.
library;

class ManifestExam {
  const ManifestExam({
    required this.id,
    required this.version,
    required this.title,
    required this.file,
    required this.sha256,
    this.category,
    this.questionCount,
    this.updatedAt,
  });

  factory ManifestExam.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final version = json['version'];
    final title = json['title'];
    final file = json['file'];
    final sha256 = json['sha256'];
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
        !RegExp(r'^[A-Za-z0-9_./-]+\.json$').hasMatch(file) ||
        file.split('/').contains('..')) {
      throw const FormatException(
          'manifest exam: file مسار JSON صالح مثل exams/quran_qalon.json');
    }
    if (sha256 is! String || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sha256)) {
      throw const FormatException(
          'manifest exam: sha256 يجب أن يكون قيمة hex بطول 64');
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
      sha256: sha256.toLowerCase(),
      category: category as String?,
      questionCount: count is int && count >= 0 ? count : null,
      updatedAt: updatedAt as String?,
    );
  }

  final String id;
  final int version;
  final String title;
  final String file;
  final String sha256;
  final String? category;
  final int? questionCount;
  final String? updatedAt;

  bool isNewerThan(int local) => version > local;

  Map<String, Object?> toJson() => {
        'id': id,
        'version': version,
        'title': title,
        'file': file,
        'sha256': sha256,
        if (category != null) 'category': category,
        if (questionCount != null) 'questionCount': questionCount,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };
}

class ContentManifest {
  const ContentManifest({
    required this.schemaVersion,
    required this.contentVersion,
    required this.exams,
    this.updatedAt,
  });

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

  final int schemaVersion;
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
