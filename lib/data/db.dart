import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  static Database? _db;

  /// Returns the app's SQLite database, copying `assets/app_data.sqlite`
  /// into the documents directory on first run.
  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'app_data.sqlite');
    if (!await File(dbPath).exists()) {
      final data = await rootBundle.load('assets/app_data.sqlite');
      await File(dbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    _db = await openDatabase(dbPath);
    return _db!;
  }

  // ---- lookups -----------------------------------------------------------

  static Future<List<Map<String, Object?>>> categories() async {
    final db = await instance;
    return db.query('categories', orderBy: 'sort_order');
  }

  static Future<List<Map<String, Object?>>> subcategories(int categoryId) async {
    final db = await instance;
    return db.query('subcategories',
        where: 'category_id = ?', whereArgs: [categoryId], orderBy: 'sort_order');
  }

  static Future<List<Map<String, Object?>>> topics(int subcategoryId) async {
    final db = await instance;
    return db.query('topics',
        where: 'subcategory_id = ?', whereArgs: [subcategoryId], orderBy: 'name');
  }
}
