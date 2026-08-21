import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../models/category.dart';

/// Data access for the `categories` table.
class CategoryRepository {
  CategoryRepository({Database? db}) : _db = db;

  /// Maximum allowed length for a category name.
  static const int maxNameLength = 12;

  final Database? _db;

  Future<Database> get _database async => _db ?? await AppDatabase.database;

  Future<List<Category>> getAll() async {
    final db = await _database;
    final results =
        await db.query('categories', orderBy: 'sort_order ASC, name ASC');
    return results.map((m) => Category.fromMap(m)).toList();
  }

  Future<Category?> getById(int id) async {
    final db = await _database;
    final results =
        await db.query('categories', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return Category.fromMap(results.first);
  }

  Future<Category?> getByName(String name) async {
    final db = await _database;
    final results = await db.query('categories',
        where: 'name = ?', whereArgs: [name], limit: 1);
    if (results.isEmpty) return null;
    return Category.fromMap(results.first);
  }

  Future<int> insert(Category category) async {
    _validate(category);
    final db = await _database;
    return db.insert('categories', category.toMap());
  }

  Future<int> update(Category category) async {
    _validate(category);
    final db = await _database;
    return db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  /// Defensive guard so the DB never holds an over-long or empty name,
  /// regardless of the caller. UI-level checks live in [CategoryDialog].
  void _validate(Category category) {
    final name = category.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('Category name must not be empty');
    }
    if (name.length > maxNameLength) {
      throw ArgumentError(
          'Category name must be $maxNameLength characters or fewer');
    }
  }

  /// Deletes a category; tasks referencing it fall back to General via
  /// the FK ON DELETE SET NULL plus this method re-parenting them.
  Future<void> delete(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      final general = await _ensureGeneral(txn);
      await txn.update('tasks', {'category_id': general},
          where: 'category_id = ?', whereArgs: [id]);
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Ensures a 'General' category exists and returns its id.
  Future<int> ensureGeneral() async {
    final db = await _database;
    return _ensureGeneral(db);
  }

  Future<int> _ensureGeneral(DatabaseExecutor db) async {
    final rows = await db.query('categories',
        where: 'name = ?', whereArgs: ['General'], limit: 1);
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return db.insert('categories', {
      'name': 'General',
      'color': 'primary',
      'sort_order': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
