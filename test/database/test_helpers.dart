import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/migrations.dart';
import 'package:taskflow/database/schema.dart';

/// Opens a fresh in-memory database with the full v2 schema and seeded
/// categories. Call this in `setUp` for each test.
Future<Database> createTestDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: AppSchema.version,
      onCreate: Migrations.onCreate,
    ),
  );
}

/// Date-only helper for building test dates.
DateTime date(int year, int month, int day) => DateTime(year, month, day);
