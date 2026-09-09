# Qalon App — AI Development Agent Rules

## 1. Core Principle

This project is a Flutter quiz application.

The application must separate:

- UI
- Quiz engine
- Question data
- Local storage
- Remote content

Never mix these responsibilities.

---

## 2. Source of Truth

The current project files are always the source of truth.

NEVER regenerate an entire Dart file from an older version.

Before modifying any file:

1. Read the current file.
2. Identify existing fixes.
3. Preserve all working behavior.
4. Make the smallest required change.

Never replace a current file with a previously generated version.

---

## 3. Regression Prevention

Before every modification:

- Inspect the current implementation.
- Check for previous bug fixes.
- Do not remove existing functionality unless explicitly requested.

Known critical areas:

- exam.dart
- exam_cat.dart
- result.dart
- db.dart
- main.dart

Special attention must be given to:

- answer selection
- answer confirmation
- question navigation
- finishing an exam
- retrying an exam
- theme scoping
- local database access

---

## 4. Architecture

Use this architecture:

```
UI
↓
Exam Engine (exam.dart)
↓
ExamRepository
↓
LocalDataSource / GithubDataSource
```

The UI must not directly access GitHub.

The exam engine must not know whether questions came from GitHub or SQLite.

---

## 5. Question Data

Questions are data, not Dart code.

Remote questions must be stored as JSON.

Every exam must have:

- id
- version
- title
- questions

Every question must have:

- id
- type
- question
- options when applicable
- correct answer when applicable

The schema must be versioned.

---

## 6. GitHub Content

GitHub is the remote content source.

The app downloads:

`manifest.json`

The manifest contains:

- schemaVersion
- contentVersion
- exam id
- exam version
- exam file
- question count

The app compares the remote version with the locally stored version.

If the remote version is newer:

Download → Validate → Store → Activate.

Never activate invalid or incomplete content.

---

## 7. Offline First

The application must work without internet.

If GitHub is unavailable:

Use the latest valid local version.

A network failure must never prevent an already downloaded exam from working.

---

## 8. Safe Updates

Never delete the current working exam before the new exam has been:

1. Downloaded
2. Parsed
3. Validated
4. Stored successfully

Only then activate the new version.

If anything fails, keep the previous version.

---

## 9. JSON Validation

Validate:

- required fields
- schema version
- exam id
- version
- unique question IDs
- valid answer indexes
- valid question types
- required options
- non-empty question text

Invalid content must be rejected safely.

---

## 10. Git / File Safety

Never modify unrelated files.

Never overwrite a file blindly.

Never revert previous fixes.

Before committing changes:

- inspect git diff
- inspect changed files
- ensure no accidental deletion
- ensure no old code has been restored

---

## 11. Flutter Rules

Do not assume Flutter compilation succeeds.

If Flutter/Dart is unavailable, explicitly state that compilation could not be performed.

Do not claim a build passed unless it was actually executed.

---

## 12. Change Strategy

For every task:

1. Understand the requested change.
2. Inspect affected files.
3. Plan the smallest change.
4. Modify only required code.
5. Review the diff.
6. Check for regressions.
7. Run formatting/tests when available.
8. Report exactly what was changed.

Never perform large-scale rewrites unless explicitly requested.

---

## 13. Adding New Question Types

New question types must be implemented through the question model and quiz engine.

Do not hard-code question types into GitHub download logic.

The remote data layer only delivers data.

The exam engine decides how to render and evaluate question types.

---

## 14. Backward Compatibility

Existing locally stored questions must continue working after updates.

Schema migrations must be explicit.

Never silently invalidate existing user data.

---

## 15. Priority

Priority order:

1. Correctness
2. Preserve existing fixes
3. Offline functionality
4. Data integrity
5. Maintainability
6. UI improvements
7. Optimization

Do not sacrifice correctness for speed of implementation.

---

## 16. Content Schema Rule

The content schema is a contract between the app and future remote content.

Never change the schema silently.

Any breaking schema change must:

1. Increment schemaVersion.
2. Document the migration.
3. Preserve compatibility with existing installed content whenever reasonably possible.

Do not design SQLite tables before the content schema is reviewed and committed.

The JSON content schema is the source contract.
Database representation is an implementation detail.

---

## Roadmap (frozen at v1.0-modern-dark)

| Version | Work |
| --- | --- |
| v1.0 | Install current app and fix bugs |
| v1.1 | Separate Question/Exam from exam.dart |
| v1.15 | Content schema contract (docs/content-schema/) |
| v1.2 | Add ExamRepository + SQLite |
| v1.3 | Add manifest.json + GitHub downloader |
| v1.4 | Auto-update + Offline + validation |
| v2.0 | New question types + advanced content management |

First AI task priority: Question Model + ExamRepository, NOT GitHub download.