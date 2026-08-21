import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'schema.dart';

/// Versioned, idempotent migration chain.
///
/// `onCreate` runs [AppSchema.createAll] (fresh database at [AppSchema.version]).
/// `onUpgrade` runs every migration between the old and new version.
/// New schema changes in future releases are appended as new versioned
/// steps here — never by editing [AppSchema.createAll].
class Migrations {
  Migrations._();

  static Future<void> onCreate(Database db, int version) async {
    await db.execute(AppSchema.createAll);
    await _seedDefaults(db);
  }

  static Future<void> onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // v2: per-project custom kanban statuses (columns).
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE project_statuses (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id  INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
          name        TEXT NOT NULL,
          color       TEXT NOT NULL DEFAULT 'primary',
          sort_order  INTEGER NOT NULL DEFAULT 0,
          created_at  TEXT NOT NULL
        );
        CREATE INDEX idx_project_statuses_project ON project_statuses(project_id);
      ''');
    }

    // v3: routine descriptions (shown on the today's-checklist cards).
    if (oldVersion < 3) {
      await db.execute(
          "ALTER TABLE routines ADD COLUMN description TEXT NOT NULL DEFAULT ''");
    }

    // v4: focus-session pause support (paused_at marks a paused, still
    // active session).
    if (oldVersion < 4) {
      await db.execute(
          "ALTER TABLE focus_sessions ADD COLUMN paused_at TEXT");
    }

    // The v1 -> v2 importer is NOT a schema migration. It reads the legacy
    // `task_recorder_pro.db` file and is implemented in Phase 1.
  }

  static Future<void> _seedDefaults(Database db) async {
    final defaults = [
      ('General', 'primary'),
      ('Work', 'primary'),
      ('Study', 'blue'),
      ('Health', 'emerald'),
      ('Personal', 'indigo'),
      ('Development', 'primary'),
      ('Design', 'indigo'),
    ];
    for (final (name, color) in defaults) {
      await db.insert('categories', {
        'name': name,
        'color': color,
        'sort_order': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }
}
