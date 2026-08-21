# TaskFlow v2 — Execution Plan

> **Start date:** 14 August 2026
> **Target release:** v2.0.0
> **Developer:** solo
> **Platform:** Flutter Windows Desktop
> **Reference:** [ARCHITECTURE.md](./ARCHITECTURE.md)

---

## How to Read This Document

- **Phases** are sequential — each phase's first task depends on the prior phase being complete.
- **Milestones** are checkpoints where the app is buildable and testable, even if features are incomplete.
- **Tasks** are ordered within each phase — do them top-down unless a dependency says otherwise.
- **Acceptance Criteria** define "done" for each phase — the app must pass all criteria before moving on.
- **Effort estimates** assume a solo developer with Flutter experience.

---

## Phase 0 — Project Bootstrap

> **Goal:** Create a buildable Flutter project named `taskflow` with all infrastructure in place — no screens yet.

| # | Task | Deliverable | Notes |
|---|---|---|---|
| 0.1 | Create Flutter project in this workspace | `pubspec.yaml`, `lib/main.dart` | `flutter create --org com.taskflow --project-name taskflow .` |
| 0.2 | Add dependencies | `pubspec.yaml` | `sqflite_common_ffi`, `path_provider`, `provider`, `fl_chart`, `csv`, `file_picker`, `shared_preferences`, `windows_notification`, `package_info_plus`, `intl` |
| 0.3 | Add dev dependencies | `pubspec.yaml` | `flutter_lints`, `flutter_launcher_icons`, `msix`, `flutter_test` |
| 0.4 | Set up app entry point | `lib/main.dart` | Rename class to `TaskFlowApp`; init FFI; `MultiProvider` root; `MaterialApp` with light/dark theme support |
| 0.5 | Set up theme system | `lib/theme/app_theme.dart`, `app_colors.dart` | Copy v1 themes, rename references, keep `AppThemeColors` ThemeExtension |
| 0.6 | Create directory skeleton | All folders | `lib/models`, `lib/providers`, `lib/services`, `lib/repositories`, `lib/screens`, `lib/widgets`, `lib/components`, `lib/database` |
| 0.7 | Fix database location | `lib/database/app_database.dart` | `getApplicationSupportDirectory()` for all modes (debug + release). DB file: `taskflow.db` |
| 0.8 | Create migration skeleton | `lib/database/migrations.dart` | Versioned migration chain using `PRAGMA user_version`; v2 create-v2 tables; ready for v1 importer later |
| 0.9 | Configure MSIX + launcher icons | `pubspec.yaml` | Update MSIX identity, display name, icon path |
| 0.10 | Run `flutter analyze` and fix issues | 0 issues | Verify clean build before any feature work |

**Acceptance criteria for Phase 0:**
- [ ] `flutter build windows` succeeds
- [ ] `flutter analyze` returns 0 issues
- [ ] App launches and shows a blank screen with the correct app name
- [ ] `taskflow.db` is created in the app support directory on first launch
- [ ] All directory names and package references use `taskflow` (no `task_recorder_pro` anywhere)

---

## Phase 1 — Data Layer + Models + Repositories

> **Goal:** Complete database schema, all models, and repositories — no UI yet. All CRUD operations working against SQLite.

| # | Task | Deliverable | Dependencies |
|---|---|---|---|
| 1.1 | Define all models | `lib/models/` | — |
| | — `Category` (id, name, color, icon, sort_order) | `category.dart` | |
| | — `Tag` (id, name, color) | `tag.dart` | |
| | — `Project` (id, title, description, color, status, start/due, timestamps, deleted_at) | `project.dart` | |
| | — `Task` (id, title, desc, category_id, project_id, priority, status, dates, times, sort_order, recurrence, parent_id, deleted_at, archived_at) | `task.dart` | |
| | — `Subtask` (id, task_id, title, is_completed, sort_order) | `subtask.dart` | |
| | — `Routine` (id, title, scheduled_time, days_of_week, color, streak, completion state, notification) | `routine.dart` | |
| | — `FocusSession` (id, task_id, started_at, ended_at, duration, session_type) | `focus_session.dart` | |
| 1.2 | Create full schema v2 | `lib/database/schema.dart` | 1.1 |
| | All tables, constraints, indexes from ARCHITECTURE.md §7.1–7.3 | `schema_v2.sql` reference | |
| 1.3 | Build migration chain | `lib/database/migrations.dart` | 1.2 |
| | — v1 → v2 importer (detects old DB, copies data, marks as migrated) | | |
| | — Future-proof migration scaffold | | |
| 1.4 | Build repositories | `lib/repositories/` | 1.1 |
| | — `CategoryRepository` (CRUD + default seeding) | `category_repository.dart` | |
| | — `TagRepository` (CRUD) | `tag_repository.dart` | |
| | — `ProjectRepository` (CRUD, progress query, kanban fetch) | `project_repository.dart` | |
| | — `TaskRepository` (CRUD, filtered list, range queries, batch analytics) | `task_repository.dart` | |
| | — `SubtaskRepository` (CRUD, toggle, reorder) | `subtask_repository.dart` | |
| | — `RoutineRepository` (CRUD, daily reset, streak update) | `routine_repository.dart` | |
| | — `FocusSessionRepository` (start/stop, daily summary, total by task) | `focus_session_repository.dart` | |
| 1.5 | Build services | `lib/services/` | 1.4 |
| | — `TaskService` (complete, subtask auto-complete, timer, soft delete) | `task_service.dart` | |
| | — `RecurrenceService` (parse rule, compute instances in range, spawn next) | `recurrence_service.dart` | |
| | — `ProjectService` (progress, auto-complete/reopen, kanban move) | `project_service.dart` | |
| | — `RoutineService` (streak logic, day-of-week match) | `routine_service.dart` | |
| | — `FocusService` (session lifecycle, break threshold) | `focus_service.dart` | |
| 1.6 | Seed default categories | `lib/database/seed.dart` | 1.2 |
| | General, Work, Study, Health, Personal, Development, Design | | |
| 1.7 | Write repository + service unit tests | `test/` | 1.4, 1.5 |
| | CRUD operations, streak math, subtask auto-complete, recurrence expansion | | |

**Acceptance criteria for Phase 1:**
- [ ] All models have `toMap`, `fromMap`, `copyWith` — compile-time verified
- [ ] Every repository passes CRUD integration tests (real SQLite, not mocked)
- [ ] `TaskService.complete` auto-completes when all subtasks done; `ProjectService` auto-closes projects
- [ ] `RoutineService` correctly increments/resets streaks based on day matching
- [ ] Default categories exist after fresh DB creation
- [ ] `flutter analyze` still 0 issues

---

## Phase 2 — State Management + App Shell + Navigation

> **Goal:** All providers wired, sidebar navigation working, screen placeholders rendering.

| # | Task | Deliverable | Dependencies |
|---|---|---|---|
| 2.1 | Build all providers | `lib/providers/` | 1.5 |
| | — `ThemeProvider` (mode, accent, persistence) | `theme_provider.dart` | |
| | — `TasksProvider` (list, filters, selection) | `tasks_provider.dart` | |
| | — `CalendarProvider` (viewing month, selected date, day tasks) | `calendar_provider.dart` | |
| | — `ProjectsProvider` (list, active project, board state) | `projects_provider.dart` | |
| | — `RoutinesProvider` (list, today state) | `routines_provider.dart` | |
| | — `FocusProvider` (active session, history) | `focus_provider.dart` | |
| | — `AnalyticsProvider` (cached aggregates, invalidation) | `analytics_provider.dart` | |
| | — `SettingsProvider` (categories, notifications, about) | `settings_provider.dart` | |
| 2.2 | Build event bus | `lib/core/event_bus.dart` | — |
| | `EventBus` singleton; events: `TaskCreated`, `TaskCompleted`, `TaskDeleted`, `ProjectChanged`, etc. | | |
| 2.3 | Build AppShell | `lib/app_shell.dart` | 2.1 |
| | Sidebar + `IndexedStack` of 8 screen shells (placeholders); collapsed drawer mode | | |
| 2.4 | Build Sidebar | `lib/widgets/sidebar.dart` | 2.3 |
| | Navigation items, logo, version; responsive collapse; notification bell | | |
| 2.5 | Build screen placeholders | `lib/screens/` | 2.3 |
| | Each screen renders a header bar + centered "Coming Soon" for now | | |
| 2.6 | Wire MultiProvider | `lib/main.dart` | 2.1 |
| | All 8 providers in correct dependency order at the root | | |

**Acceptance criteria for Phase 2:**
- [ ] App launches with sidebar; all 8 tabs navigate correctly
- [ ] Sidebar collapses to drawer on narrow windows
- [ ] Theme toggles work (light/dark/system)
- [ ] Each screen placeholder is visible
- [ ] `flutter analyze` 0 issues

---

## Phase 3 — Core Screens: Tasks + Dashboard + Routines + Projects

> **Goal:** The three most-used screens fully functional. Users can create, edit, complete, and manage tasks, view the dashboard, track routines, and organize projects.

| # | Task | Deliverable | Dependencies |
|---|---|---|---|
| **3A: Task Dialog** | | | |
| 3.1 | Build task dialog | `lib/widgets/task_dialog.dart` | 1.1, 1.4 |
| | All fields: title, description, category (dropdown from categories table), priority, status, scheduled date + time, due date, project, tags, subtask editor, timer toggle | | |
| 3.2 | Build subtask editor widget | `lib/widgets/subtask_editor.dart` | 3.1 |
| | Inline add/reorder/complete/delete; keyboard shortcut for add | | |
| **3B: Tasks Screen** | | | |
| 3.3 | Build task card (grid) | `lib/widgets/task_card.dart` | 1.1 |
| 3.4 | Build list task item | `lib/components/tasks/list_task_item.dart` | 1.1 |
| 3.5 | Build filter chip bar | `lib/components/tasks/filter_chip_bar.dart` | 2.1 |
| 3.6 | Build tasks screen | `lib/screens/tasks_screen.dart` | 3.1–3.5 |
| | Grid/list toggle, search, stacked filters, click → task dialog, long-press → delete, bulk actions | | |
| 3.7 | Implement timer ticking (local ticker, not global) | Task card uses `ValueNotifier` + 1s `Timer` | 3.3 |
| **3C: Dashboard** | | | |
| 3.8 | Build dashboard header | `lib/components/dashboard/dashboard_header.dart` | — |
| 3.9 | Build KPI cards | `lib/components/dashboard/kpi_cards_row.dart` | 2.1 |
| 3.10 | Build weekly bar chart | `lib/components/dashboard/weekly_bar_chart.dart` | 1.4 |
| 3.11 | Build category donut | `lib/components/dashboard/category_donut.dart` | 1.4 |
| 3.12 | Build recent tasks table | `lib/components/dashboard/recent_tasks_table.dart` | 1.4 |
| 3.13 | Build today's agenda | `lib/components/dashboard/today_agenda.dart` (new) | 1.4 |
| 3.14 | Build quick-add bar | `lib/components/dashboard/quick_add.dart` (new) | 3.1 |
| 3.15 | Assemble dashboard screen | `lib/screens/dashboard_screen.dart` | 3.8–3.14 |
| **3D: Routines** | | | |
| 3.16 | Build routine dialog | `lib/widgets/routine_dialog.dart` | 1.1 |
| | Fields: title, time, days-of-week checkboxes, color, notification toggle | | |
| 3.17 | Build routine card | `lib/components/routines/routine_card.dart` | 1.1 |
| 3.18 | Build routines screen | `lib/screens/routines_screen.dart` | 3.16–3.17 |
| | Groups by Morning/Afternoon/Evening; completion toggle; streak display; CRUD | | |
| **3E: Projects** | | | |
| 3.19 | Build project dialog | `lib/widgets/project_dialog.dart` | 1.1 |
| 3.20 | Build project card | `lib/components/projects/project_card.dart` | 1.1 |
| 3.21 | Build project detail (kanban) | `lib/screens/project_detail_screen.dart` (new) | 1.4, 1.5 |
| | Stats overview + 3-column kanban (Pending / In Progress / Completed); drag cards to move | | |
| 3.22 | Build projects screen | `lib/screens/projects_screen.dart` | 3.19–3.21 |
| **3F: Project Integration** | | | |
| 3.23 | Wire project selector into task dialog | Task dialog → dropdown to pick project | 3.1, 3.19 |
| 3.24 | Wire project auto-complete | ProjectService recalculates on every task change | 1.5, 2.2 |

**Acceptance criteria for Phase 3:**
- [ ] Create a task with all fields (title, description, category, priority, status, date/time, due, project, tags, subtasks); it appears in the Tasks list
- [ ] Edit a task; changes persist
- [ ] Delete a task with confirmation dialog
- [ ] Start and stop a timer on a task; elapsed time is correct and persisted
- [ ] Grid/list toggle works; all stacked filters work together
- [ ] Dashboard shows KPIs, charts, and today's agenda
- [ ] Quick-add creates a task and it appears everywhere
- [ ] Create a routine with time + days; it appears in the correct group
- [ ] Toggle routine completion; streak increments correctly
- [ ] Create a project; assign a task to it; project progress bar updates
- [ ] Kanban drag moves task status; project auto-completes when all tasks done
- [ ] All screens responsive (collapsed + full sidebar layouts)
- [ ] `flutter analyze` 0 issues

---

## Phase 4 — Calendar + Focus Timer

> **Goal:** Calendar with drag-and-drop scheduling; dedicated focus timer with session history.

| # | Task | Deliverable | Dependencies |
|---|---|---|---|
| **4A: Calendar** | | | |
| 4.1 | Build calendar header | `lib/components/calendar/calendar_header.dart` | 2.1 |
| | Month/year selector, view mode toggle (month/week/day/agenda), today button | | |
| 4.2 | Build month view | `lib/components/calendar/calendar_grid.dart` | 1.1, 1.4 |
| | Month grid with completion dots/counts; drag-drop reschedule (persisted); click → day detail | | |
| 4.3 | Build week view | `lib/components/calendar/week_view_grid.dart` | 4.2 |
| | 7-column layout; tasks in time slots; drag within and across days | | |
| 4.4 | Build day view | `lib/components/calendar/day_detail_panel.dart` | 4.2 |
| | Timeline with time slots; task list with drag reorder; quick complete; add task on this day | | |
| 4.5 | Build agenda view | `lib/components/calendar/agenda_list.dart` (new) | 4.2 |
| | Chronological list of all tasks in range; expandable sections by date | | |
| 4.6 | Assemble calendar screen | `lib/screens/calendar_screen.dart` | 4.1–4.5 |
| 4.7 | Persist day-view task order | `sort_order` column + reorder API | 1.4, 4.4 |
| **4B: Focus Timer** | | | |
| 4.8 | Build focus timer widget | `lib/widgets/focus_timer.dart` (new) | 1.5 |
| | Circular progress, start/pause/stop, configurable duration, attached task name | | |
| 4.9 | Build session log | `lib/components/focus/session_log.dart` (new) | 1.4 |
| | Today's sessions list, total focus time, per-task breakdown | | |
| 4.10 | Build focus screen | `lib/screens/focus_screen.dart` (new) | 4.8–4.9 |
| 4.11 | Wire focus → task timer | FocusService auto-starts task timer when session attaches | 1.5, 3.7 |

**Acceptance criteria for Phase 4:**
- [ ] Month view shows task dots/count for each day; click opens day detail
- [ ] Drag a task to another day; `scheduled_date` persists on restart
- [ ] Week view shows tasks in correct day columns
- [ ] Day view allows drag-reorder; `sort_order` persists
- [ ] Agenda shows chronological task list
- [ ] View mode toggle switches between month/week/day/agenda
- [ ] Focus timer starts, pauses, stops; duration recorded in `focus_sessions`
- [ ] Focus session attached to a task starts the task timer automatically
- [ ] Session log shows today's sessions correctly
- [ ] `flutter analyze` 0 issues

---

## Phase 5 — Analytics + Notifications + Reports

> **Goal:** Full analytics dashboard; fixed notification system; CSV backup/restore.

| # | Task | Deliverable | Dependencies |
|---|---|---|---|
| **5A: Analytics** | | | |
| 5.1 | Build `AnalyticsService` batched queries | `lib/services/analytics_service.dart` | 1.4 |
| | Single SQL per metric: productivity score, daily streak, max streak, avg completion, focus time per day, category performance | | |
| 5.2 | Build stat cards | `lib/components/analytics/stat_card.dart` | 5.1 |
| 5.3 | Build focus time chart (week/month) | `lib/components/analytics/focus_time_chart.dart` | 5.1 |
| 5.4 | Build category radar chart | `lib/components/analytics/category_radar.dart` | 5.1 |
| 5.5 | Build weekly report preview | `lib/components/analytics/weekly_report_preview.dart` | 5.1 |
| 5.6 | Build analytics screen | `lib/screens/analytics_screen.dart` | 5.2–5.5 |
| **5B: Notifications** | | | |
| 5.7 | Fix break reminder (per-session, not per-task) | `NotificationService` rewrite | 1.5, 4.11 |
| 5.8 | Fix routine reminders (once per routine per day) | `RoutineService` + notification state | 1.5 |
| 5.9 | Build notification center dropdown | `lib/components/common/notification_menu.dart` | 2.4, 5.7–5.8 |
| 5.10 | Add notification settings to Settings | Toggle switches for breaks, routines, daily summary | 2.1 |
| **5C: CSV Export/Import** | | | |
| 5.11 | Build `ReportingService` | `lib/services/reporting_service.dart` | 1.4 |
| | Tasks CSV export/import (v1-compatible format), analytics CSV export, weekly report CSV | | |
| 5.12 | Wire export/import into Settings | File picker buttons in data section | 5.11 |

**Acceptance criteria for Phase 5:**
- [ ] Analytics screen shows productivity score, streaks, avg completion, focus charts
- [ ] Charts toggle between week and month views
- [ ] Weekly report shows summary + comparison + insights
- [ ] Break reminder fires at threshold; does NOT fire again if session is still running
- [ ] Routine reminders fire once per routine per day
- [ ] Export tasks CSV; re-import; all tasks preserved correctly (v1 format compatible)
- [ ] Export analytics CSV; file opens in Excel correctly
- [ ] Notification center shows active timers and due-today alerts
- [ ] `flutter analyze` 0 issues

---

## Phase 6 — Backup/Restore + Trash + Tags + Settings Polish

> **Goal:** Data safety (backup/restore/trash), tag system, polished settings.

| # | Task | Deliverable | Dependencies |
|---|---|---|---|
| 6.1 | Build JSON backup | `BackupService.export()` | 1.4 |
| | Dump all tables to a single timestamped JSON file via file picker | | |
| 6.2 | Build JSON restore | `BackupService.import()` | 6.1 |
| | Read JSON; show preview (table counts); replace or merge option; run in transaction | | |
| 6.3 | Build trash system | `TaskRepository.trash()` / `restore()` / `permanentDelete()` / `empty()` | 1.4 |
| | Soft-delete: set `deleted_at`; filter from main list; trash panel shows deleted items | | |
| 6.4 | Build trash UI | `lib/components/tasks/trash_panel.dart` (new) | 6.3 |
| | Accessible from Tasks header; restore / permanent delete / empty trash | | |
| 6.5 | Build tag CRUD | `TagRepository` + dialog | 1.4 |
| 6.6 | Wire tags into task dialog | Tag selector with add-new-inline | 3.1, 6.5 |
| 6.7 | Wire tags into filter bar | Tag filter chips in Tasks | 3.5, 6.5 |
| 6.8 | Build settings: categories management | Add/rename/recolor/delete categories | 2.1 |
| 6.9 | Build settings: focus preferences | Pomodoro durations, auto-start toggle | 2.1 |
| 6.10 | Build settings: about section | Version, changelog link, license | — |

**Acceptance criteria for Phase 6:**
- [ ] Full JSON backup creates a file; full restore recreates all data exactly
- [ ] Merge restore adds new records without duplicating existing
- [ ] Trash a task; it disappears from list; restore puts it back; permanent delete removes it
- [ ] Empty trash deletes all trashed items
- [ ] Create a tag; assign to a task; filter by tag shows correct tasks
- [ ] Add/rename/delete categories from Settings; changes reflected in task dialog dropdowns
- [ ] Settings about shows correct version from `package_info_plus`
- [ ] `flutter analyze` 0 issues

---

## Phase 7 — Onboarding + Command Palette + UI Polish

> **Goal:** First-run experience, keyboard shortcuts, final visual polish.

| # | Task | Deliverable | Dependencies |
|---|---|---|---|
| 7.1 | Build onboarding screen | `lib/screens/onboarding_screen.dart` (new) | — |
| | Welcome, name, theme choice, sample data toggle; completion flag in SharedPreferences | | |
| 7.2 | Wire onboarding gate | `lib/main.dart` checks flag; shows onboarding or app shell | 7.1 |
| 7.3 | Build command palette | `lib/widgets/command_palette.dart` (new) | 2.1 |
| | Ctrl+K trigger; fuzzy search tasks/projects/routines; quick actions (new task, navigate) | | |
| 7.4 | Build global search overlay | `lib/widgets/global_search_overlay.dart` (new) | 7.3 |
| | Instant results as you type; keyboard navigation; enter → open | | |
| 7.5 | Polish: loading states | Skeleton loaders for all screens | — |
| 7.6 | Polish: empty states | Custom empty-state illustrations for each screen | — |
| 7.7 | Polish: keyboard shortcuts | Ctrl+K (palette), Ctrl+N (new task), Ctrl+S (save), Esc (close dialog) | 7.3 |
| 7.8 | Polish: error handling | Graceful DB errors, network-free app but show user-friendly toasts on failures | — |
| 7.9 | Build app icon | `assets/icon/app_icon.png` | — |
| 7.10 | Configure launcher icon generation | `flutter_launcher_icons` config in `pubspec.yaml` | 7.9 |

**Acceptance criteria for Phase 7:**
- [ ] First launch shows onboarding; subsequent launches skip it
- [ ] Ctrl+K opens command palette; search works across all entities
- [ ] Ctrl+N opens new task dialog from any screen
- [ ] Skeleton loaders appear while data loads (not blank screens)
- [ ] Empty states show helpful messages, not blank areas
- [ ] Keyboard shortcuts work; Esc closes any dialog
- [ ] App icon displays correctly in taskbar and start menu
- [ ] `flutter analyze` 0 issues

---

## Phase 8 — Testing

> **Goal:** Comprehensive test coverage — unit, integration, widget.

| # | Task | Deliverable | Dependencies |
|---|---|---|---|
| 8.1 | Unit tests: TaskService | `test/services/task_service_test.dart` | 1.5 |
| | Subtask auto-complete, timer accounting, soft delete | | |
| 8.2 | Unit tests: RoutineService | `test/services/routine_service_test.dart` | 1.5 |
| | Streak increment/reset, day-of-week matching, daily reset | | |
| 8.3 | Unit tests: ProjectService | `test/services/project_service_test.dart` | 1.5 |
| | Progress calculation, auto-complete/reopen, kanban status move | | |
| 8.4 | Unit tests: RecurrenceService | `test/services/recurrence_service_test.dart` | 1.5 |
| | Rule parsing, instance computation, next-occurrence spawn | | |
| 8.5 | Unit tests: FocusService | `test/services/focus_service_test.dart` | 1.5 |
| | Session lifecycle, break threshold, duration accounting | | |
| 8.6 | Unit tests: AnalyticsService | `test/services/analytics_service_test.dart` | 5.1 |
| | Productivity score, streaks, focus-time aggregation | | |
| 8.7 | Unit tests: ReportingService CSV | `test/services/reporting_service_test.dart` | 5.11 |
| | Export/import round-trip; v1 format compatibility; edge cases (empty, special chars) | | |
| 8.8 | Integration tests: repositories | `test/repositories/` | 1.4 |
| | Full CRUD + query tests against real SQLite (in-memory or temp file) | | |
| 8.9 | Integration tests: v1 → v2 importer | `test/database/v1_import_test.dart` | 1.3 |
| | Create a v1-format DB in memory, run importer, verify all data | | |
| 8.10 | Widget tests: core screens | `test/screens/` | All screens |
| | Smoke tests: each screen renders without crash; key interactions work | | |
| 8.11 | Code coverage report | `coverage/lcov.info` | 8.1–8.10 |
| | Target: ≥80% on services, ≥60% on repositories | | |

**Acceptance criteria for Phase 8:**
- [ ] `flutter test` passes all unit tests
- [ ] `flutter test integration_test/` passes all integration tests
- [ ] Code coverage meets targets
- [ ] No `print()` statements in `lib/` (only in test scratch files, if any)
- [ ] `flutter analyze` still 0 issues

---

## Phase 9 — Packaging + Release

> **Goal:** Signed MSIX installer, Inno Setup build, versioned release, documentation.

| # | Task | Deliverable | Dependencies |
|---|---|---|---|
| 9.1 | Version bump | `pubspec.yaml` → `version: 2.0.0` | — |
| 9.2 | Create version constant | `lib/core/app_version.dart` | 9.1 |
| | `const String appVersion = '2.0.0';` derived from pubspec or generated | | |
| 9.3 | Update README | `README.md` | 9.1 |
| | Features list, screenshots, install instructions, changelog for v2 | | |
| 9.4 | Generate MSIX installer | `flutter build msix` | 9.1 |
| | Test install and launch on clean Windows machine | | |
| 9.5 | Build Inno Setup installer | `TaskFlow_Setup_v2.0.0.exe` | 9.4 |
| | Same test as 9.4 | | |
| 9.6 | Test v1 → v2 data migration | Manual + automated | 1.3, 8.9 |
| | Install v1 → create data → install v2 → verify all data migrated | | |
| 9.7 | Smoke test all screens | Manual walkthrough | All phases |
| | Every screen: create, edit, delete; edge cases: empty state, large data, rapid clicking | | |
| 9.8 | Performance check | Profiler / frame analysis | — |
| | No frame drops during normal use; timer doesn't cause jank; charts render smoothly | | |
| 9.9 | Write CHANGELOG.md | `CHANGELOG.md` | 9.1 |
| 9.10 | Tag release | `git tag v2.0.0` | 9.1–9.9 |

**Acceptance criteria for Phase 9:**
- [ ] MSIX installs on a clean Windows machine without errors
- [ ] Inno Setup installs and launches correctly
- [ ] v1 data migrates to v2 without data loss
- [ ] All screens pass manual smoke test
- [ ] No frame drops; timer doesn't cause jank
- [ ] README is accurate and includes screenshots
- [ ] CHANGELOG documents all v2 changes
- [ ] Release tagged in git

---

## Summary Timeline

```
Phase 0 — Project Bootstrap  ████████░░░░░░░░░░░░░░░░░░  Week 1
Phase 1 — Data + Models     ████████████░░░░░░░░░░░░░░  Weeks 1–2
Phase 2 — Shell + Nav       ████░░░░░░░░░░░░░░░░░░░░░░  Week 2
Phase 3 — Tasks/Dash/Rout/Proj  ████████████████░░░░░░░  Weeks 2–4
Phase 4 — Calendar + Focus  ████████████░░░░░░░░░░░░░░  Weeks 4–5
Phase 5 — Analytics + Notif  ████████░░░░░░░░░░░░░░░░░░  Weeks 5–6
Phase 6 — Backup/Trash/Tags  ████████░░░░░░░░░░░░░░░░░░  Week 6
Phase 7 — Onboarding + Polish  ████████░░░░░░░░░░░░░░░░  Week 7
Phase 8 — Testing           ████████████░░░░░░░░░░░░░░  Weeks 7–8
Phase 9 — Packaging + Release  ████████░░░░░░░░░░░░░░░░  Week 8
```

**Total: ~8 weeks** for a solo developer working part-time. Faster if you prioritize M1–M4 and defer M6–M7 polish.

---

## Key Decisions Log

| Decision | Chosen | Rationale |
|---|---|---|
| State management | Provider (keep v1 choice) | Already proven in v1; lower churn; riverpod migration is a v3 concern |
| Database ORM | Raw sqflite + repositories | Drift adds learning curve; v2 repository pattern gives 90% of the benefit with zero new deps |
| Subtask storage | Normalized table (not JSON) | Enables proper ordering, individual queries, drag-reorder |
| Recurring tasks | Compute instances in memory, not stored rows | Keeps DB small; recurrence rules are the source of truth |
| Timer rebuilds | Local `ValueNotifier` per card | Fixes v1's 1-second global rebuild problem |
| Backup format | JSON (full dump) | Human-readable, easy to restore, includes schema version for future migrations |
| Version management | `pubspec.yaml` as single source | `package_info_plus` reads at runtime; `app_version.dart` for compile-time constants |
