# TaskFlow v2 — System Architecture

> Version: 2.0.0 (draft)
> Platform: Flutter — Windows Desktop (MSIX + Inno Setup)
> Source: rewrite of v1 (`stitch_task_management`, ~12k LOC)

---

## 1. Overview

TaskFlow v2 is a full rewrite of the v1 Windows desktop task-management app. It keeps everything v1 did well — layered structure, theme system, streaks, CSV import/export, per-task timers — and rebuilds the weak spots:

| Area | v1 problem | v2 design |
|---|---|---|
| Data location | DB written next to the EXE (breaks under MSIX / Program Files) | DB in `getApplicationSupportDirectory()` |
| State | One 600-line `AppState`; 1s global `notifyListeners()` rebuilds the whole tree | Focused providers; per-task local tickers |
| Data model | Categories are free-text strings; subtasks stored as JSON blob; no ordering persistence | Normalized `categories` + `subtasks` tables; `sort_order` persisted |
| Queries | N+1 everywhere (7 queries per weekly chart; project status loads all rows) | Batched analytics SQL + indexes |
| Notifications | Break reminder fires once per task *forever*; state leaks | Per-session reminder state, persisted settings |
| Branding | `task_recorder_pro` package, `TaskRecorderProApp`, `task_recorder_pro.db` | Full rename to `taskflow` |
| Features | — | Focus timer, recurring tasks, kanban board, tags, trash, backup/restore, command palette, onboarding |

---

## 2. High-Level Architecture

```
┌───────────────────────────── Presentation ─────────────────────────────┐
│  screens/        Dashboard · Tasks · Calendar · Projects · Focus ·     │
│                  Routines · Analytics · Settings · Onboarding          │
│  widgets/        dialogs, cards, reusable controls                     │
│  components/     page-specific building blocks (headers, charts, ...)  │
│  global/         command palette, notification center, toasts          │
└───────────────────────────────▲────────────────────────────────────────┘
                                │ notifies / reads
┌───────────────────────────────┴────────────── State ───────────────────┐
│  providers/   Theme · Tasks · Calendar · Projects · Routines ·         │
│               Focus · Analytics · Settings            (MultiProvider)   │
│               + event bus for cross-provider invalidation              │
└───────────────────────────────▲────────────────────────────────────────┘
                                │ calls
┌───────────────────────────────┴────────────── Domain ──────────────────┐
│  services/    TaskService · ProjectService · RoutineService ·          │
│               FocusService · AnalyticsService · ReportingService ·     │
│               NotificationService · BackupService · RecurrenceService  │
│               (pure Dart, no BuildContext — hold all business rules)    │
└───────────────────────────────▲────────────────────────────────────────┘
                                │ CRUD / queries
┌───────────────────────────────┴────────────── Data ────────────────────┐
│  repositories/  TaskRepository · ProjectRepository · RoutineRepository  │
│                 CategoryRepository · SubtaskRepository ·                │
│                 FocusSessionRepository · TagRepository                  │
│  database/      schema v2 · migration chain · seed data · indexes      │
└─────────────────────────────────────────────────────────────────────────┘
                SQLite via sqflite_ffi  →  taskflow.db
                (getApplicationSupportDirectory() — fixed for MSIX)
```

**Layer rules**

- **Presentation** never touches the database or services directly; it reads providers and calls provider methods.
- **Providers** hold UI state (lists, filters, selection, loading) and orchestrate service calls. They are the only layer that calls `notifyListeners()`.
- **Services** implement business rules (streak math, recurrence expansion, project auto-completion, CSV format, backup payloads). Pure functions where possible — unit-testable without Flutter.
- **Repositories** are the only layer that knows SQL. Each returns/accepts models.
- **Models** are immutable, with `toMap`/`fromMap`/`copyWith` (same pattern as v1).

---

## 3. Application Shell & Navigation

- `TaskFlowApp` → `MultiProvider` → `MaterialApp` (light/dark/system theme, theme extension from v1).
- `AppShell`: fixed 256px `Sidebar` + `IndexedStack` of the 8 main screens (state preserved across tabs). Below 60% of the primary display width the sidebar collapses into a drawer (keep v1 logic).
- **Command palette** (Ctrl+K) overlays all screens — global search + quick actions.
- **Cross-page navigation**: a small `AppNavigator` service lets any page request a focused view (e.g. *notification click → Calendar on that date*, *chart click → Analytics*, *task tap → Task detail dialog*).

**Screen index (stable)** — 0 Dashboard, 1 Tasks, 2 Calendar, 3 Projects, 4 Focus, 5 Routines, 6 Analytics, 7 Settings.

---

## 4. Page Specifications

### 4.1 Dashboard

**Purpose:** the at-a-glance daily command center.

**Functions**
- Render KPI cards: total tasks, completed today, pending, hours logged, productivity score, current streak.
- Today's agenda — tasks scheduled for today with one-click complete toggle.
- Quick-add bar (title + date) that expands into the full task dialog.
- Weekly completion bar chart and category distribution donut (reuse v1 chart widgets).
- Recent tasks table; row click opens the task dialog.
- Click-through shortcuts: chart → Analytics, agenda → Calendar/Tasks.

**Data:** reads batched aggregate query, today's tasks, recent tasks. Writes: task status toggles, quick-add inserts.

### 4.2 Tasks

**Purpose:** full task list management — the core of the app.

**Functions**
- Toolbar: search, stacked filters (category, status, priority, date range, project, tag), grid/list toggle, sort menu (due date, priority, created, manual).
- **Task dialog** (shared global surface): title, description, category, priority, status, scheduled date + time, due date, project, tags, subtask editor, notes, timer.
- Subtasks: add/reorder/toggle; auto-complete the task when all subtasks complete; reopen task when a subtask is un-checked (v1 logic preserved).
- Timer: start/stop per task; live elapsed shown via a **local 1s ticker on the card**, not a global rebuild.
- Recurring tasks: set a recurrence rule on create/edit; completing an instance spawns the next occurrence (see RecurrenceService).
- Bulk actions: multi-select → complete / delete / move to project / tag.
- Trash: soft-deleted items listed here (restore / permanent delete / empty trash).

**Data:** reads filtered tasks; writes tasks, subtasks, timers, recurrence.

### 4.3 Calendar

**Purpose:** schedule, reschedule, and reorder tasks by date.

**Functions**
- Month view (completion dots / counts), Week view (day columns), Day view (time-based), Agenda (chronological list).
- **Drag & drop** — move a task to another day (updates `scheduled_date`) or reorder within a day (updates `sort_order`). Both persist.
- Recurring task instances expanded on read for the displayed range (not stored as rows).
- Day detail panel: task list for the selected day, quick complete, add-task-on-this-day.
- Click a task → task dialog. Reschedule also available from the dialog.

**Data:** reads tasks in range + recurrence expansion; writes `scheduled_date`, `sort_order`, task fields.

### 4.4 Projects

**Purpose:** group related tasks and track progress toward completion.

**Functions**
- Project cards: title, color, progress bar (completed/total), status badge.
- **Project detail**: overview stats (tasks, time logged, due date) + **kanban board** with columns Pending / In Progress / Completed; dragging a card changes its status (persisted immediately).
- Project CRUD dialog (title, description, color, start/due dates).
- Auto-complete the project when all its tasks are completed; reopen if any task reopens (moved from `AppState` into `ProjectService`, with a single indexed query instead of full-table scans).
- Link tasks to a project from the task dialog; bulk-move tasks into a project.

**Data:** reads projects + their tasks (single JOIN query); writes projects, `task.project_id`, `task.status`.

### 4.5 Focus Timer *(new page)*

**Purpose:** dedicated deep-work sessions with history — the Pomodoro-style engine.

**Functions**
- Start / pause / stop a focus session; default 25 min work / 5 min break, configurable in Settings.
- Attach the session to a task (optional; "unfocused" allowed).
- Session log: today's sessions, total focus time, per-task breakdown.
- Auto-start the task's own timer when a focus session on that task begins; stop both together.
- 2-hour continuous-work break reminder — tracked **per active session**, fixing v1's fires-once-forever bug.
- Today's focus ring on the Dashboard.

**Data:** reads/writes `focus_sessions`; touches task timer fields when attached.

### 4.6 Routines

**Purpose:** daily repeated habits with streaks.

**Functions**
- Routine CRUD: title, time, days-of-week, color, notification toggle.
- Daily completion checkbox; streak increments on completion, resets when a scheduled day is missed (v1 logic moved into `RoutineService` and unit-tested).
- Grouped by Morning / Afternoon / Evening; weekly strip showing which days each routine applies.
- Reminders at scheduled time — in-app dialog when visible, Windows toast otherwise; once per routine per day.

**Data:** reads/writes `routines` (streaks, completion state).

### 4.7 Analytics & Reports

**Purpose:** productivity insight over time.

**Functions**
- Stat cards: productivity score, current & max streak, average completion time.
- Charts: focus time per day (week/month toggle), category performance radar, completion trend line.
- Weekly report: summary, previous-week comparison, auto-generated insights (v1 `generateWeeklyReport` + insights preserved).
- Exports: tasks CSV, analytics CSV, weekly report CSV.
- Scope filter: date range applied to charts.

**Data:** reads batched analytics queries (no N+1); writes nothing (exports via file picker).

### 4.8 Settings

**Purpose:** configuration and data management.

**Functions**
- Appearance: theme mode (light/dark/system), accent color, font scale.
- Categories: add / rename / recolor / delete categories (now a real table; deleting re-parents tasks to General).
- Notifications: master toggle, break threshold (hours), routine reminders on/off.
- Focus: pomodoro durations, auto-start task timer.
- Data: CSV export & import (v1-compatible format), **JSON backup & restore** (full DB dump with replace/merge choice), reset all data.
- About: version, changelog, license.

**Data:** reads/writes `settings`/SharedPreferences, `categories`, backup files.

### 4.9 Onboarding *(new page)*

**Purpose:** first-run setup.

**Functions**
- Welcome, optional name entry, theme preference.
- Offer to load sample data or start empty.
- Completion flag persisted; never shown again.

**Data:** writes settings only.

### 4.10 Global Surfaces

- **Command palette (Ctrl+K)** — fuzzy-search tasks/projects/routines; quick actions: *New Task*, *New Project*, *Go to page*; keyboard-first.
- **Notification center** — bell dropdown: active timers, due-today alerts, routine reminders; click navigates to the item.
- **Task detail dialog** — shared across every page (replaces per-page dialogs).
- **Trash panel** — soft-deleted items, restore / permanent delete / empty.

---

## 5. State Management

Replace the single `AppState` with **focused providers** under `MultiProvider`:

| Provider | Owns |
|---|---|
| `ThemeProvider` | theme mode, accent color |
| `TasksProvider` | task list, filters, sort, selection, running timers |
| `CalendarProvider` | viewing month, selected date, day tasks, view mode |
| `ProjectsProvider` | projects, active project, board drag state |
| `RoutinesProvider` | routines, today's completion, streaks |
| `FocusProvider` | active session, session history, pomodoro settings |
| `AnalyticsProvider` | cached aggregates + reports, invalidation |
| `SettingsProvider` | categories, notifications, focus prefs, about |

**Key design decisions**

- **Timer ticking is scoped.** Each running-task card owns a local `ValueNotifier`/`Ticker` that ticks every second. Only the card rebuilds — no 1-second global `notifyListeners()`.
- **Analytics invalidation.** Providers publish events on a small **event bus** (`TaskCreated`, `TaskCompleted`, `TaskDeleted`, ...). `AnalyticsProvider` subscribes and recomputes its cached aggregates — lazily, only when the Analytics page is visible.
- **Cross-provider flows** go through services, not provider-to-provider calls: e.g. kanban drag → `ProjectService.moveTaskStatus(...)` → Tasks + Analytics invalidate via the bus.

---

## 6. Services Layer (business rules live here)

| Service | Responsibilities |
|---|---|
| `TaskService` | task CRUD orchestration, subtask auto-complete logic, timer start/stop (elapsed accounting), bulk operations, soft delete |
| `RecurrenceService` | parse `recurrence_rule`, compute instances in a range, spawn next occurrence on completion |
| `ProjectService` | progress calculation, auto-complete/reopen, kanban status moves |
| `RoutineService` | streak increment/reset rules, daily reset, day-of-week matching |
| `FocusService` | session lifecycle, duration accounting, break-threshold logic |
| `AnalyticsService` | productivity score, streaks, focus-time aggregation (batched SQL) |
| `ReportingService` | CSV export/import (v1 format), weekly report + insights, JSON backup/restore |
| `NotificationService` | in-app dialogs, Windows toasts, per-session reminder state |

All services are pure Dart (no `BuildContext`, no widgets) → unit-testable.

---

## 7. Database Design

**File:** `taskflow.db` in `getApplicationSupportDirectory()` — same path in debug and release. This fixes v1's fatal "write next to the executable" behavior under MSIX and Program Files installs.

### 7.1 Schema v2

```sql
-- Lookup tables
CREATE TABLE categories (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT NOT NULL UNIQUE,
  color       TEXT NOT NULL DEFAULT 'primary',   -- color key, as in v1
  icon        TEXT,                              -- optional material icon name
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
  status       TEXT NOT NULL DEFAULT 'Pending',   -- Pending | Completed
  start_date   TEXT,
  due_date     TEXT,
  created_at   TEXT NOT NULL,
  updated_at   TEXT,
  deleted_at   TEXT                               -- soft delete -> trash
);

CREATE TABLE tasks (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  title              TEXT NOT NULL,
  description        TEXT NOT NULL DEFAULT '',
  category_id        INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  project_id         INTEGER REFERENCES projects(id)  ON DELETE SET NULL,
  priority           TEXT NOT NULL DEFAULT 'Medium', -- High | Medium | Low
  status             TEXT NOT NULL DEFAULT 'Pending',-- Pending | In Progress | Completed
  scheduled_date     TEXT,                           -- yyyy-MM-dd
  scheduled_time     TEXT,                           -- HH:mm
  due_date           TEXT,                           -- deadline (nullable)
  created_at         TEXT NOT NULL,
  updated_at         TEXT,
  completed_at       TEXT,
  time_spent_seconds INTEGER NOT NULL DEFAULT 0,
  timer_started_at   TEXT,
  sort_order         INTEGER NOT NULL DEFAULT 0,     -- manual order within a day
  recurrence_rule    TEXT,                           -- e.g. 'FREQ=WEEKLY;BYDAY=MO,WE'
  recurrence_end_date TEXT,
  parent_task_id     INTEGER,                        -- recurring instances reference the master
  deleted_at         TEXT,                           -- soft delete -> trash
  archived_at        TEXT
);

CREATE TABLE subtasks (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id      INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  is_completed INTEGER NOT NULL DEFAULT 0,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL
);

CREATE TABLE routines (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  title               TEXT NOT NULL,
  scheduled_time      TEXT NOT NULL,                 -- HH:mm
  days_of_week        TEXT NOT NULL DEFAULT '0,1,2,3,4,5,6', -- comma-separated ISO weekdays
  color               TEXT NOT NULL DEFAULT 'primary',
  streak              INTEGER NOT NULL DEFAULT 0,
  is_completed_today  INTEGER NOT NULL DEFAULT 0,
  last_completed_date TEXT,
  notification_enabled INTEGER NOT NULL DEFAULT 1,
  created_at          TEXT NOT NULL
);

-- Focus sessions (new)
CREATE TABLE focus_sessions (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id          INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
  started_at       TEXT NOT NULL,
  ended_at         TEXT,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  session_type     TEXT NOT NULL DEFAULT 'pomodoro', -- pomodoro | manual
  created_at       TEXT NOT NULL
);

-- Many-to-many
CREATE TABLE task_tags (
  task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  tag_id  INTEGER NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
  PRIMARY KEY (task_id, tag_id)
);
```

### 7.2 Relationships

```
categories 1───N tasks  N───1 projects
tasks      1───N subtasks
tasks      1───N focus_sessions
tasks      N───M tags          (via task_tags)
tasks      1───N tasks         (parent_task_id — recurring instances)
```

- Deleting a project → tasks keep existing, `project_id` set NULL (v1 behavior).
- Deleting a category → tasks fall back to a `General` category (SET NULL + default on read).
- Deleting a task → subtasks and tags cascade; focus sessions keep their row but detach (`SET NULL`) so history survives.

### 7.3 Indexes

```sql
CREATE INDEX idx_tasks_scheduled_date ON tasks(scheduled_date);
CREATE INDEX idx_tasks_status        ON tasks(status);
CREATE INDEX idx_tasks_project_id    ON tasks(project_id);
CREATE INDEX idx_tasks_category_id   ON tasks(category_id);
CREATE INDEX idx_tasks_completed_at  ON tasks(completed_at);
CREATE INDEX idx_tasks_deleted_at    ON tasks(deleted_at);
CREATE INDEX idx_subtasks_task_id    ON subtasks(task_id);
CREATE INDEX idx_focus_sessions_task ON focus_sessions(task_id);
CREATE INDEX idx_focus_sessions_started ON focus_sessions(started_at);
```

### 7.4 Migrations

- Use SQLite `PRAGMA user_version`; each migration is a versioned, idempotent function (`if oldVersion < N → apply`).
- Migrations only ever go forward; every schema change ships as a new migration, never an edit to the v2 create script.
- Repository layer exposes `Database get db` (same lazy singleton pattern as v1).

### 7.5 v1 → v2 data import

One-time importer, run on first launch of v2 when a v1 DB is detected (`task_recorder_pro.db`). It reads the v1 file **read-only** and writes into `taskflow.db`:

| v1 | v2 |
|---|---|
| `tasks` rows | `tasks` rows (copy fields; `category` string → `categories` row, then FK) |
| `tasks.subtasks` JSON blob | one `subtasks` row per item (order preserved) |
| `projects` | `projects` (copy) |
| `routines` | `routines` with `days_of_week = '0,1,2,3,4,5,6'` (daily, as v1 behaved) |
| — | `categories` seeded from all distinct v1 category strings + defaults |

Completion stored as a settings flag; the v1 file is never modified or deleted.

---

## 8. Data Flow Examples

**1. Complete a task from the Dashboard agenda**
`TasksProvider.toggleComplete(task)` → `TaskService.complete(task)` (transaction: set status/completed_at, bank elapsed timer, spawn next recurring occurrence if any) → repository update → emit `TaskCompleted` event → `ProjectsProvider` re-evaluates project status, `AnalyticsProvider` invalidates → UI updates on the Dashboard, Tasks, Calendar, Projects simultaneously.

**2. Drag a task to another day in Calendar**
Calendar gesture → `TaskService.reschedule(task, date)` → `tasks.scheduled_date = date`, `sort_order = 0` → repository → event bus → calendar + agenda refresh. Order within the day uses `sort_order` and survives restarts.

**3. Start a focus session on a task**
`FocusProvider.start(task)` → `FocusService` inserts `focus_sessions` row + starts task timer → card's local ticker begins; stop → duration written, `tasks.time_spent_seconds += duration`, timer cleared → Analytics invalidates.

---

## 9. Non-Functional Design

- **Theming:** keep `AppTheme` + `AppThemeColors` ThemeExtension; add selectable accent color and font scale in Settings.
- **Responsiveness:** reuse `isScreenCollapsed` logic; all new pages must render both fixed-sidebar and drawer layouts.
- **Notifications:** Windows toasts via `windows_notification` when minimized; in-app dialogs when visible; reminder state is **per active session** (no leaks); settings persisted.
- **Performance:** batched analytics (single `GROUP BY` queries), indexes above, scoped timers, cached analytics with invalidation.
- **Backup/restore:** full JSON dump of all tables; restore wizard with *replace* or *merge*; one-click CSV round-trip kept.
- **Naming:** package `taskflow`, app class `TaskFlowApp`, DB `taskflow.db`, display name **TaskFlow**, version `2.0.0` defined once in `pubspec.yaml` and surfaced via `package_info_plus`.
- **Testing:** unit tests for services (streaks, recurrence, subtask auto-complete, CSV round-trip), integration tests for repositories + migrations, widget smoke tests per screen.

---

## 10. Suggested Build Order

| Milestone | Scope |
|---|---|
| **M1 — Foundation** | Rename + DB location fix, schema v2 + migrations + importer, repositories, Theme/Tasks/Projects/Routines providers, Tasks + Dashboard + Routines screens working |
| **M2 — Scheduling** | Calendar (month/week/day/agenda), drag & drop persistence, kanban in Projects, recurring tasks |
| **M3 — Focus & Analytics** | Focus timer + sessions, batched AnalyticsService, notification fixes, command palette |
| **M4 — Data & Polish** | Backup/restore, trash, onboarding, tags, settings expansion, accents |
| **M5 — Ship** | Full test pass, MSIX + Inno builds, version alignment, 2.0.0 release |
