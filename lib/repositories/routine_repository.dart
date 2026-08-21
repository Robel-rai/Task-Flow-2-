import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../models/routine.dart';

/// Data access for the `routines` table.
class RoutineRepository {
  RoutineRepository({Database? db}) : _db = db;

  final Database? _db;

  Future<Database> get _database async => _db ?? await AppDatabase.database;

  Future<List<Routine>> getAll() async {
    final db = await _database;
    final results = await db.query('routines', orderBy: 'scheduled_time ASC');
    return results.map((m) => Routine.fromMap(m)).toList();
  }

  Future<Routine?> getById(int id) async {
    final db = await _database;
    final results =
        await db.query('routines', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return Routine.fromMap(results.first);
  }

  Future<int> insert(Routine routine) async {
    final db = await _database;
    return db.insert('routines', routine.toMap());
  }

  Future<int> update(Routine routine) async {
    final db = await _database;
    return db.update('routines', routine.toMap(),
        where: 'id = ?', whereArgs: [routine.id]);
  }

  Future<int> delete(int id) async {
    final db = await _database;
    return db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }
}
