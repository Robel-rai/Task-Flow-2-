/// Schema v4 — all CREATE TABLE statements and indexes.
///
/// The full schema is applied only when a fresh database is created.
/// Incremental changes are added to [Migrations] instead, never here.
library;

class AppSchema {
  AppSchema._();

  /// Current schema version (PRAGMA user_version).
  static const int version = 4;

  static const String createAll = '''
    -- Lookup tables
    CREATE TABLE categories (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      name        TEXT NOT NULL UNIQUE,
      color       TEXT NOT NULL DEFAULT 'primary',
      icon        TEXT,
      sort_order  INTEGER NOT NULL DEFAULT 0,
      created_at  TEXT NOT NULL
    );

    CREATE TABLE tags (
      id      INTEGER PRIMARY KEY AUTOINCREMENT,
      name    TEXT NOT NULL UNIQUE,
      color   TEXT NOT NULL DEFAULT 'primary'
    );

    -- Core entities
    CREATE TABLE projects (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      title        TEXT NOT NULL,
      description  TEXT NOT NULL DEFAULT '',
      color        TEXT NOT NULL DEFAULT 'primary',
      status       TEXT NOT NULL DEFAULT 'Pending',
      start_date   TEXT,
      due_date     TEXT,
      created_at   TEXT NOT NULL,
      updated_at   TEXT,
      deleted_at   TEXT
    );

    CREATE TABLE tasks (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      title               TEXT NOT NULL,
      description         TEXT NOT NULL DEFAULT '',
      category_id         INTEGER REFERENCES categories(id) ON DELETE SET NULL,
      project_id          INTEGER REFERENCES projects(id)  ON DELETE SET NULL,
      priority            TEXT NOT NULL DEFAULT 'Medium',
      status              TEXT NOT NULL DEFAULT 'Pending',
      scheduled_date      TEXT,
      scheduled_time      TEXT,
      due_date            TEXT,
      created_at          TEXT NOT NULL,
      updated_at          TEXT,
      completed_at        TEXT,
      time_spent_seconds  INTEGER NOT NULL DEFAULT 0,
      timer_started_at    TEXT,
      sort_order          INTEGER NOT NULL DEFAULT 0,
      recurrence_rule     TEXT,
      recurrence_end_date TEXT,
      parent_task_id      INTEGER,
      deleted_at          TEXT,
      archived_at         TEXT
    );

    CREATE TABLE subtasks (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      task_id      INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      title        TEXT NOT NULL,
      is_completed INTEGER NOT NULL DEFAULT 0,
      sort_order   INTEGER NOT NULL DEFAULT 0,
      created_at   TEXT NOT NULL
    );

    CREATE TABLE project_statuses (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id  INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
      name        TEXT NOT NULL,
      color       TEXT NOT NULL DEFAULT 'primary',
      sort_order  INTEGER NOT NULL DEFAULT 0,
      created_at  TEXT NOT NULL
    );

    CREATE TABLE routines (
      id                    INTEGER PRIMARY KEY AUTOINCREMENT,
      title                 TEXT NOT NULL,
      description           TEXT NOT NULL DEFAULT '',
      scheduled_time        TEXT NOT NULL,
      days_of_week          TEXT NOT NULL DEFAULT '1,2,3,4,5,6,7',
      color                 TEXT NOT NULL DEFAULT 'primary',
      streak                INTEGER NOT NULL DEFAULT 0,
      is_completed_today    INTEGER NOT NULL DEFAULT 0,
      last_completed_date   TEXT,
      notification_enabled  INTEGER NOT NULL DEFAULT 1,
      created_at            TEXT NOT NULL
    );

    -- Focus sessions
    CREATE TABLE focus_sessions (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      task_id          INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
      started_at       TEXT NOT NULL,
      ended_at         TEXT,
      paused_at        TEXT,
      duration_seconds INTEGER NOT NULL DEFAULT 0,
      session_type     TEXT NOT NULL DEFAULT 'pomodoro',
      created_at       TEXT NOT NULL
    );

    -- Many-to-many
    CREATE TABLE task_tags (
      task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      tag_id  INTEGER NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
      PRIMARY KEY (task_id, tag_id)
    );

    -- Indexes
    CREATE INDEX idx_tasks_scheduled_date ON tasks(scheduled_date);
    CREATE INDEX idx_tasks_status         ON tasks(status);
    CREATE INDEX idx_tasks_project_id     ON tasks(project_id);
    CREATE INDEX idx_tasks_category_id    ON tasks(category_id);
    CREATE INDEX idx_tasks_completed_at   ON tasks(completed_at);
    CREATE INDEX idx_tasks_deleted_at     ON tasks(deleted_at);
    CREATE INDEX idx_subtasks_task_id     ON subtasks(task_id);
    CREATE INDEX idx_project_statuses_project ON project_statuses(project_id);
    CREATE INDEX idx_focus_sessions_task  ON focus_sessions(task_id);
    CREATE INDEX idx_focus_sessions_started ON focus_sessions(started_at);
  ''';
}
