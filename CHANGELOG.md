# Changelog

All notable changes to TaskFlow are documented here.

## [2.0.0] - 2026-08-21

### Added

#### Dashboard
- Daily agenda showing scheduled and due tasks
- Quick-add tasks directly from the dashboard
- Recent tasks overview
- KPI cards with productivity metrics

#### Tasks
- Full task CRUD with subtasks, priorities, and custom statuses
- Category and project assignment
- Scheduled dates, due dates, and time tracking with start/stop timer
- Tag system for flexible organization
- Grid and list view modes
- Drag-to-reorder in day view
- Inline subtask editing (click to rename)
- Trash and restore for soft-deleted tasks
- Recurring tasks (daily, weekly, monthly) with auto-spawn on completion

#### Calendar
- Month, week, day, and agenda views
- Drag-and-drop rescheduling between days
- Visual task chips with status and priority colors
- Recurring task expansion across the calendar

#### Projects & Kanban
- Project creation with color, description, and date range
- Kanban board with drag-and-drop status transitions
- Custom columns per project (add, rename, delete, reorder)
- Auto-completion when all project tasks are done
- Progress tracking (completed/total)

#### Focus Timer
- Pomodoro-style focus sessions with configurable duration
- Pause, resume, and stop controls
- Break threshold reminders (2 hours)
- Session log with date range filtering
- Optional task attachment for automatic time tracking

#### Routines & Habits
- Daily habit tracking with streak counters
- Customizable schedules (which days of the week)
- Color-coded routine cards with descriptions
- In-app and Windows toast notifications for reminders
- Automatic daily reset and streak management

#### Analytics & Insights
- Productivity score (0–100) based on completions and focus time
- Current and longest completion streaks
- Weekly completion bar charts
- Focus time per day aggregation
- Category performance breakdown
- CSV export for analytics and weekly reports

#### Settings
- Light and dark theme with full color customization
- Font family selection (Montserrat, System, Roboto)
- Sidebar navigation reordering
- Category management with custom colors (max 12 chars)
- Notification scheduling preferences
- Shortcuts customization page
- Backup & restore (CSV export/import)
- Data migration from TaskFlow v1 (Task Recorder Pro)

#### Command Palette
- Global search across tasks and projects (`Ctrl + K`)
- Quick actions (new task, new project, new routine, toggle theme)
- Navigation shortcuts to any screen
- Recent search history

#### Keyboard Shortcuts
- Customizable keyboard shortcuts for all major actions
- `Ctrl+K` command palette, `Ctrl+N` new task, `Ctrl+S` save dialog
- `Esc` close dialogs, `Ctrl+1-8` navigate screens
- All shortcuts configurable from Settings

#### UI/UX
- Responsive layout with collapsible sidebar
- Onboarding splash screen on first launch
- Notification center (bell icon) with overdue, scheduled, running timers, focus, and routine alerts
- Smooth animations and transitions
- Custom Montserrat font

#### Testing
- 100+ unit and widget tests covering services, repositories, and screens
- TaskService, RoutineService, ProjectService, RecurrenceService, FocusService, AnalyticsService, ReportingService all tested
- Repository integration tests with in-memory SQLite
- V1 → V2 data migration tests
- Widget smoke tests for all core screens

#### Packaging
- Windows desktop build (x64)
- Inno Setup installer script
- MSIX packaging support

### Changed
- Complete rewrite from TaskFlow v1 (Task Recorder Pro)
- Migrated from raw SQL to structured repository pattern
- Migrated from single-table schema to normalized multi-table schema
- Migrated from basic notifications to Windows toast notifications
- Migrated from simple list view to kanban board for projects

### Fixed
- Ctrl+S and Escape no longer cause a black screen when pressed outside a dialog
- Sidebar search bar now shows keyboard shortcut pill

### Removed
- Legacy single-table database schema (migrated via v1 importer)
- Dashboard search bar (replaced by global command palette)
