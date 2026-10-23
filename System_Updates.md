# TaskFlow v2 — System Updates & Audit Report

> Generated: 2026-10-22
> Scope: Full codebase audit (lib/ — screens, widgets, components, providers, services, repositories, database, core; windows/runner; pubspec; test coverage)
> Method: Read-only static analysis. No code was modified.
> Status: **Findings only — no development started.** Items await approval.

---

## Summary

TaskFlow v2 is a layered Flutter Windows desktop task manager:

```
screens/ widgets/ components/   (Presentation)
providers/ (10, MultiProvider)  (State)        + core/event_bus.dart cross-invalidation
services/  (13, pure Dart)      (Domain)
repositories/ (8)               (Data)
database/   schema v2 + migrations + v1 importer → SQLite via sqflite_ffi
```

The architecture is solid and matches ARCHITECTURE.md. ~40 test files cover services, repositories, and screens. The issues below are specific, verified gaps — most are data-loss risks in the backup/restore paths, silent-failure UX in write operations, an eager event cascade causing redundant work on every task mutation, and one flagship feature (recurring tasks) that is present in the backend but unreachable from the UI.

Finding ID prefixes: **S** = Security, **U** = UI Flow, **E** = Efficiency, **F** = Missing Feature.

---

## 🔴 SECURITY

| ID | Severity | Location | Finding |
|----|----------|----------|---------|
| S1 | 🔴 High | `lib/services/backup_service.dart:96-119` (+ `settings_screen.dart` restore surface) | **SQL injection via crafted backup import.** `importJson` passes attacker-controlled JSON row keys straight into `sqflite`'s `txn.insert(table, map)`. sqflite builds the `INSERT INTO ... (col1, col2 ...)` column list by string interpolation — values are parameterized but **column names are not escaped**. A malicious/shared JSON "backup" file can carry keys crafted as SQL fragments → arbitrary SQL executed on the app database (including `DROP TABLE`). Mitigation: whitelist/validate column names against the known schema before insert. |
| S2 | 🔴 High | `lib/screens/settings_screen.dart:966-1035`, `lib/services/backup_service.dart:88-94` | **Unvalidated destructive restore.** The "Restore Database" JSON path wipes all 9 tables first (`merge: false`) then replays the file, with only `preview.isEmpty` as validation (e.g. `{"foo":[1]}` passes) and **no try/catch and no safety snapshot taken beforehand** — unlike `AutoBackupService.restoreNow`, which validates against known tables and takes a safety backup (`auto_backup_service.dart:296-313`). Restoring a wrong or truncated file = permanent data loss. |
| S3 | 🟠 Med | `lib/services/auto_backup_service.dart:388-402`, `296-313` | **Silent scheduled destructive restore.** With "Automatic restore" enabled, the newest `taskflow_auto_backup_*.json` in the folder is restored (full DB replace) with no user confirmation and only a shallow preview check. A semi-valid or planted file silently replaces live data; failures are only logged via `debugPrint`. |
| S4 | 🟠 Med | `lib/services/auto_backup_service.dart:296-302`, `backup_service.dart:125-140` | **Shallow backup validation.** Preview only checks top-level keys are `List`. A truncated but valid-shaped backup (e.g. `{"tasks": []}`) passes validation and still wipes the DB. Safety backup is also skipped if one was taken in the last 6h (`_hadRecentSafetyBackup`, lines 436-440). Validation should parse rows and verify schema version / row shapes. |
| S5 | 🟠 Med | `lib/models/task.dart:92-93`, `lib/models/routine.dart:115` | **Crash loop from crafted values.** `DateTime.parse(map['created_at'] as String)` throws on non-date/int values; rows restored from a partial/crafted backup make every `Task.fromMap` fail → all task screens crash on every launch with no repair path. Should use `DateTime.tryParse` + null-safe cast (neighboring fields already do this). |
| S6 | 🟠 Med | `lib/services/reporting_service.dart:128`, `lib/widgets/task_dialog.dart:280-282`, `lib/screens/settings_screen.dart:237-254` | **CSV import data-driven crashes.** (a) Imported `scheduled_time` is never validated as `HH:mm`; opening such a task throws `FormatException` from bare `int.parse` in the task dialog. (b) `_importTasksCsv` uses `utf8.decode(await file.readAsBytes())` with no try/finally — a non-UTF-8 file throws, leaving `_importing = true` and permanently disabling the Import button until app restart. |
| S7 | 🟠 Med | `lib/services/reporting_service.dart:59-79` (also 158-173) | **CSV formula injection on export.** Task title/description/subtask cells are exported verbatim without neutralizing leading `=`, `+`, `-`, `@`, tab. Opening the CSV in Excel can execute embedded formulas/hyperlinks. (Analytics/weekly exports are numeric, lower risk.) |
| S8 | 🟡 Low | `task_dialog.dart:402-420`, `tag_dialog.dart:70-75`, `routine_dialog.dart:182-202`, `project_dialog.dart:166-179`, `subtask_editor.dart:114-122`, `onboarding_screen.dart:174-180` | **No input length caps.** Task/project/routine titles & descriptions, tag and subtask names, and the onboarding name accept unbounded text; oversized values persist into exports and chart labels. Contrast: `category_dialog.dart:96-102` correctly caps at 12 chars. |
| S9 | 🟡 Low | `lib/app_shell.dart:228-247` (+ `tasks_screen.dart`, `projects_screen.dart`, `routines_screen.dart` call sites; `tasks_provider.dart:318-484`) | **Silent fire-and-forget DB writes.** Awaited CRUD futures have no catch anywhere in the call chain; any DB failure (disk error, constraint) is silently lost with no user feedback. |
| S10 | 🟡 Low | `lib/services/notification_service.dart:369-386` | **Privacy in toasts.** Task titles are rendered into Windows toast notifications, which persist in the OS notification center and may appear on the lock screen. No setting to suppress content. |

### Verified clean (no action needed)

- SQL injection in the query layer: all ~18 repository `rawQuery` calls use `?` placeholders; `orderBy` from a whitelist (`task_repository.dart:17-25`); `IN (...)` built with `List.filled(n,'?')`. The **only** injection sink is S1.
- No zip/archive code (zip-slip N/A); no path traversal in backup paths (fixed prefixes + timestamps).
- `windows_registry.dart` / `startup_service.dart`: benign HKCU-only writes, hardcoded value name, `reconcile()` removes only its own entry, failures never block launch.
- Windows runner C++ is the standard template (DPI handled properly; only reads OS dark-mode registry).
- `shared_preferences` holds no secrets; no logging of user data.
- v1 importer (`v1_importer.dart`) is read-only on the legacy file, fully try/catch-guarded, parameterized inserts, transactional.
- DB open handles unwritable install dirs with an AppData fallback (`app_database.dart:61-77`).

---

## 🧭 UI FLOW

| ID | Severity | Location | Finding |
|----|----------|----------|---------|
| U1 | 🔴 High | `lib/app_shell.dart:219-224` (global) | **Esc and Ctrl+S both discard work.** The global handler just `Navigator.pop()`s the root navigator. Ctrl+S is advertised as "Save the current open dialog" (`shortcuts_provider.dart:81`) but actually **closes the dialog without saving** — false affordance + data loss. There is **no `PopScope`/`WillPopScope` anywhere in lib** (grep-verified), and dialogs default to `barrierDismissible: true`, so scrim clicks also silently discard typed text. |
| U2 | 🔴 High | `lib/widgets/task_dialog.dart:302-315`, `:343` | **Silent failure on duplicate tag.** `_showAddTagDialog` awaits `TagRepository().insert(result)` with no try/catch; `tags.name` is UNIQUE (`schema.dart:26`) → uncaught SQLite exception, no snackbar/dialog, no error sound. `_deleteTag` (:343) is equally unhandled. Inconsistent: `categories_page.dart:58-141` *does* catch and show "already exists" for the identical flow. |
| U3 | 🟠 Med | `lib/main.dart:68-79`, `lib/widgets/splash_page.dart:37-38`, `lib/database/v1_importer.dart:58-60` | **Blocking opaque startup + migration with zero UX.** DB open → v1 migration → ghost cleanup → registry reconcile all run *before the window shows*, then a **forced 2-second splash timer** on every launch. The `V1ImportResult` is discarded: import errors are never surfaced, the completion flag isn't set on error → **the import re-runs every launch**; there is no "Imported N tasks" success feedback anywhere. Skip-list silently drops v1 tasks (`v1_importer.dart:253-265`) without telling the user. |
| U4 | 🟠 Med | `lib/main.dart:83-93`, `lib/widgets/app_title_bar.dart:162-165` | **No window continuity.** Window size/position is never persisted (no `getBounds`/`setBounds` usage — grep-verified); every launch opens at default size. Close = instant `windowManager.close()` — no minimize/close-to-tray (`tray_manager` absent), no close confirmation, so active task timers and focus sessions are killed instantly on quit. |
| U5 | 🟠 Med | `lib/screens/dashboard_screen.dart:63-145`, `:33-37` | **Dashboard has no loading gate.** KPIs/charts render directly with zero values and pop in late (no `loading` check, unlike Analytics). The "Hello, $userName" greeting also pops in later from prefs. |
| U6 | 🟡 Low | `lib/services/notification_service.dart:352-366`, `:376`, `:393` | **Toast deep-link promised but not implemented.** Toasts are sent via `showNotificationPluginTemplate` with no press callback, despite copy saying "Tap to open TaskFlow." Clicking a notification does nothing. |
| U7 | 🟡 Low | `components/settings/shortcuts_page.dart:96-100`, `lib/app_shell.dart:209-216` | **Shortcut footguns.** (a) No conflict detection when rebinding — two actions can share a combo (first-match wins). (b) `Ctrl+1–8` navigate by **fixed screen index**, contradicting the sidebar order after reordering (the numbers shown next to nav items no longer match). |
| U8 | 🟡 Low | `lib/screens/tasks_screen.dart:40, 291-295`, `lib/widgets/global_search.dart:21-31`, `:84-90` | **State/navigation leaks.** (a) Trash panel's `_showTrash` survives across screen switches — returning later lands inside Trash unexpectedly. (b) Double `Ctrl+K` spawns duplicate search overlays (no open-guard). (c) Palette "New Project/Routine" don't navigate to their screens ("New Task" does). |
| U9 | 🟡 Low | `theme/app_colors.dart:71-84`, `tasks_screen.dart:438, 450`, `today_agenda.dart:99-109`, `recent_tasks.dart:90-98`, `task_dialog.dart:383-386, 759-765`, `category_dialog.dart:112-130` | **Accessibility.** (a) Light-theme `textTertiary #94A3B8` on white ≈ 2.5:1 contrast, used for empty-state copy/subtitles/menus. (b) Hardcoded hex (`0xFF10B981`, `0xFFF43F5E`) bypass theme tokens. (c) Icon-only interactive elements (complete toggles, close button, 14px clear ✕, color swatches) lack tooltips/Semantics. |
| U10 | 🟡 Low | `screens/tasks_screen.dart:490-512, 309-313`, `screens/projects_screen.dart:141-163`, dashboard empty states | **Inconsistent empty states.** Tasks screen shows "Create your first task" even when *filters* excluded everything (misleading — needs a "no results for these filters" variant). Tasks/Projects/Dashboard empties are static text with no CTA; Analytics/Settings/search/trash have proper CTAs. `placeholder_content.dart` and `SkeletonLoader` are dead code (never referenced). |
| U11 | 🟡 Low | repo-wide | **No localization.** All strings hardcoded English; `intl` is in pubspec but `flutter_localizations` / `Intl.defaultLocale` are absent — dates always en-US regardless of Windows locale. One toast uses `d/m/y` (`notification_service.dart:370-372`) inconsistent with intl usage elsewhere. |
| U12 | 🟡 Low | `lib/widgets/task_dialog.dart:566-577` | Subtask completion counter in the TaskDialog reads `_subtasks` but `onChanged` mutates state without `setState` → the "x/y complete" count never live-updates while editing. |

### Destructive-action confirmations — mostly GOOD (leave as-is)

- Trash permanent delete / empty trash: confirmed with clear wording and item counts (`trash_panel.dart:48-104`).
- Reset Data: checkbox-gated with disabled confirm (`settings_screen.dart:1039-1157`).
- Reset Tasks by Date with empty-range feedback (`settings_screen.dart:1161-1339`).
- Focus clear-all mentions running-session effect (`focus_screen.dart:124-158`).
- Gap: JSON "Restore Database" wording says only "cannot be undone" and takes **no** safety backup, while the backup-page restore takes one first — asymmetric protection (folded into S2).

---

## ⚙️ EFFICIENCY

| ID | Severity | Location | Finding |
|----|----------|----------|---------|
| E1 | 🔴 High | `lib/providers/analytics_provider.dart:51-92` | **Analytics recomputes eagerly ~25 queries on every task mutation — even when the Analytics page was never opened.** It subscribes to 11 event-bus events and refreshes fully at startup, contradicting ARCHITECTURE.md §5 ("lazily, only when the Analytics page is visible"). Includes a full unfiltered `getAll()` of every task just to `take(5)` recent rows (`:80-83` — `limit:` param exists but is unused). |
| E2 | 🔴 High | `providers/tasks_provider.dart:94-116` + `calendar_provider.dart:63-82` + `projects_provider.dart:61-81` + `analytics_provider.dart:51-69` | **Event cascade on every mutation.** Completing one task synchronously triggers: Tasks full refresh with **double `notifyListeners` waves** (loading + loaded), Calendar `_reload` (day + month + week queries; month query can run twice via `selectDate`), Projects N+1 refresh, Analytics ~25 queries — regardless of which pages are visible — plus toast + sound + per-card event dispatch. |
| E3 | 🟠 Med | `lib/providers/projects_provider.dart:83-91` | **Projects N+1.** `refresh()` loops `await _projects.progress(p.id!)` — one COUNT query per project — and reruns the whole loop on every one of 13 subscribed task events. Should be a single `GROUP BY project_id` query (ARCHITECTURE.md §4.4 promises a single JOIN). |
| E4 | 🟠 Med | `lib/services/task_service.dart:214-225`, `reporting_service.dart:100-153`, `projects_provider.dart:148-156`, `tasks_provider.dart:416-436`, `backup_service.dart:88-119` | **No transactions around multi-write operations.** CSV import, bulk complete/delete, kanban column save, and subtask replace (`_replaceSubtasks`) each write row-by-row with sequential awaits and no wrapping transaction. `importJson` uses a transaction ✓ but row-by-row instead of `batch()`. A task save is ~7 sequential round trips (insert + subtask reconcile + re-read + project evaluate + evaluate's own reads + recurrence + re-read). |
| E5 | 🟠 Med | `lib/services/backup_service.dart:26-50`, `reporting_service.dart` export paths | **UI-thread encoding jank.** `exportJson` reads all 9 tables and JSON-encodes the entire DB (`JsonEncoder.withIndent`) into one giant string on the main isolate — multi-MB DB = frozen UI during backup. Same for large CSV exports. Should use `compute()`/isolate or batched encoding. |
| E6 | 🟡 Low | `lib/app_shell.dart:78-85`, `lib/services/auto_backup_service.dart:372, 215-233, 252-277` | **Polling + sync I/O.** Notification poll is `Timer.periodic(30s)` while the comment says 60s, and runs while idle/minimized (~7 awaited prefs reads per tick). Auto-backup tick calls `folderReady` → **synchronous** `existsSync()`; `listBackups()` uses `listSync()`/`statSync()` on the UI thread, called from settings build paths. |
| E7 | 🟡 Low | `lib/widgets/sidebar.dart:38-42, 142`, `task_card.dart:243, 66-83`, `list_task_item.dart:100`, `kpi_cards_row.dart:120-134`, `tasks_screen.dart:333-344, 210-216` | **Broad rebuilds.** Sidebar (visible on every screen, root-level `Consumer` of Tasks/Settings/Focus) rebuilds on every double-notify wave. Every visible task card `watch`es `FocusProvider` — any focus change rebuilds all cards. Each card subscribes to 5 event-bus events (O(cards) callbacks per event). KPI/stat animations restart from 0 on every analytics change. Tasks screen runs 5 separate `.where()` passes and an O(tasks × categories) `_categoryFor` scan per rebuild. |
| E8 | 🟡 Low | `lib/providers/*.dart` `initialize()` methods | **Event-bus subscriptions never unsubscribed** in `dispose()`. Harmless for app-lifetime singletons but a leak landmine for tests/refactors (torn-off `refresh` keeps firing forever). |
| E9 | 🟡 Low | `lib/main.dart:103-122` | **Eager startup work.** All 10 providers constructed and start loading immediately, including Analytics' full ~25-query summary, when only dashboard aggregates are needed early. Startup critical path (`main.dart:57-95`) also includes registry reconcile (sync FFI) and file probes before the first frame. |
| E10 | 🟡 Low | `components/calendar/month_view.dart:88-98`, `providers/calendar_provider.dart:104-116, 44-56`, `components/tasks/filter_chip_bar.dart:43-60` | **Redundant recompute on access.** Month view re-sorts every day's task list for all 42 cells on every build; agenda getter re-flattens/re-sorts the whole month map on every access; month refetched on every event/navigation without a small invalidated cache; tag list re-queried from DB every time the filter bar opens (no provider cache). |

### Verified good (no action)

- Proper indexes covering all filter columns (`schema/migrations`).
- Batched analytics `GROUP BY` SQL (no N+1 inside the analytics queries themselves).
- Command-palette/global search properly debounced 250ms with staleness guard (`core/search_controller.dart:79-108`).
- Scoped per-card 1s tickers for running timers (`task_card.dart:101-110`) — no global 1s `notifyListeners`.
- `IndexedStack` preserves all screens' state; theme rebuild gated via `Selector2` equality key (`main.dart:166-249`).
- No recurrence expansion on read/repaint (`instancesInRange` is never called from UI today — note F1/F8).
- Single-instance guard via named mutex (`main.dart:48-55`).

---

## ➕ MISSING FEATURES

| ID | Priority | Finding |
|----|----------|---------|
| F1 | 🔴 High | **Recurring tasks are advertised but unreachable.** The splash screen promises "recurring tasks on autopilot" (`splash_screen.dart:230`); schema (`tasks.recurrence_rule`, `recurrence_end_date`, `parent_task_id`), model plumbing, and `RecurrenceService` (including `nextOccurrence` spawning on completion, `task_service.dart:231`) all exist — but **no dialog or screen ever sets `recurrence_rule` on a task** (grep-verified: zero recurrence UI in `widgets/`). Users literally cannot create a recurring task. Biggest gap in the product. |
| F2 | 🟠 Med | **Archive is schema-only.** `tasks.archived_at` column + model plumbing exist; there is no UI to archive, unarchive, or view archived tasks. Either ship the feature or drop the column. |
| F3 | 🟠 Med | **Trash never auto-purges.** Soft-deleted tasks/projects sit forever; no "keep deleted items N days" policy or scheduled cleanup. |
| F4 | 🟡 Low | **No localization support.** Could ship multi-language (requires `flutter_localizations`, `.arb` resources, string extraction — ties into U11). |
| F5 | 🟡 Low | **No time-format setting.** No 12/24-hour clock preference; date/time presentation forced to en-US conventions. |
| F6 | 🟡 Low | **Global quick-add hotkey.** A capture-a-task shortcut usable even when the app is in the background/hidden; currently quick-add exists only in-app (Dashboard + Ctrl+N). |
| F7 | 🟡 Low | **Backup assurance UX.** Auto-backup only runs while the app is open and ticks every 30s; no "last backup was X days ago" warning banner and no guaranteed daily backup. |
| F8 | 🟡 Low | **Recurring-instance editing UX.** Once F1 exists, needs an "edit this occurrence / all future occurrences" decision; today only "spawn next on complete" is implemented. |

---

## ✅ Already solid — leave as-is

- Layered architecture matching its own spec (providers → services → repositories, event bus for invalidation).
- Parameterized SQL everywhere + whitelisted sort keys.
- Versioned, idempotent migration chain; fully guarded read-only v1 importer.
- ~40 test files across services, repositories, database, and screens.
- Per-card scoped 1-second tickers (exactly per architecture); session-scoped break reminders.
- Batched analytics SQL; debounced command palette; trash/soft-delete workflow.
- Mostly good destructive-action confirmations; IndexedStack state preservation; single-instance guard.

---

## Proposed Development Priority (PENDING APPROVAL — not started)

| Priority | Contents |
|----------|----------|
| **P0 — data loss & security** | S1, S2, S5, U1, E5 |
| **P1 — trust & polish** | S3, S4, S6, U2, U3, U4, E1, E2, E3, E4 |
| **P2 — fill the promise** | F1 (recurring tasks UI), F2 (archive), F3 (trash auto-purge) |
| **P3 — nice-to-have** | S7, S8, S9, S10, U5–U12, E6–E10, F4–F8 |

> **Note:** No code has been modified. Development will begin only after the owner confirms which findings to include/exclude.
