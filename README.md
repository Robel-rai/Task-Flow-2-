# TaskFlow

A modern, feature-rich task management desktop application built with Flutter for Windows.

![Version](https://img.shields.io/badge/version-2.0.0-blue)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B)

---

## Features

### Dashboard
- Daily agenda with scheduled and due tasks
- Quick-add tasks inline
- Recent tasks overview
- KPI cards for productivity metrics

### Tasks
- Create, edit, and delete tasks with subtasks
- Priority levels (High, Medium, Low) and custom statuses
- Category and project assignment
- Scheduled dates, due dates, and time tracking
- Tag system for flexible organization
- Grid and list view modes
- Drag-to-reorder in day view

### Calendar
- Month, week, day, and agenda views
- Drag-and-drop rescheduling
- Recurring task expansion
- Visual task chips with status colors

### Projects & Kanban
- Group tasks into projects with progress tracking
- Kanban board with drag-and-drop status transitions
- Custom columns per project
- Auto-completion when all tasks are done

### Focus Timer
- Pomodoro-style focus sessions with configurable duration
- Pause, resume, and stop controls
- Break reminders after extended sessions
- Session log with date range filtering
- Optional task attachment for time tracking

### Routines & Habits
- Daily habit tracking with streak counters
- Customizable schedules (which days of the week)
- Color-coded routine cards
- In-app and toast notifications for reminders

### Analytics & Insights
- Productivity score (0–100)
- Current and longest completion streaks
- Weekly completion charts
- Focus time aggregation
- Category performance breakdown
- CSV export for weekly reports

### Settings
- Light and dark theme with full color customization
- Font family selection (Montserrat, System, Roboto)
- Sidebar navigation reordering
- Category management with custom colors
- Notification scheduling preferences
- Backup & restore (CSV export/import)
- Data migration from TaskFlow v1

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl + K` | Open command palette / search |
| `Ctrl + N` | New task |
| `Ctrl + Shift + N` | New project |
| `Ctrl + Shift + R` | New routine |
| `Ctrl + F` | Toggle focus session |
| `Ctrl + S` | Save (when dialog is open) |
| `Esc` | Close dialog |
| `Ctrl + 1–8` | Navigate to screens |

All shortcuts are customizable from **Settings → Shortcuts**.

---

## Installation

### Option 1: Inno Setup Installer

1. Download `TaskFlow_Setup_v2.0.0.exe` from the releases page.
2. Run the installer and follow the prompts.
3. Launch TaskFlow from the Start Menu or Desktop shortcut.

### Option 2: Build from Source

**Prerequisites:**
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.41+)
- [Visual Studio 2022+](https://visualstudio.microsoft.com/) with the "Desktop development with C++" workload
- [Inno Setup](https://jrsoftware.org/isinfo.php) (optional, for building the installer)

**Steps:**

```bash
# Clone the repository
git clone https://github.com/your-username/taskflow.git
cd taskflow

# Install dependencies
flutter pub get

# Run in debug mode
flutter run -d windows

# Build release
flutter build windows

# Build installer (requires Inno Setup installed)
# Open TaskFlow_Setup.iss in Inno Setup and click Build → Compile
```

---

## Data Migration (v1 → v2)

If you have data from TaskFlow v1 (Task Recorder Pro), the app will automatically detect and migrate it on first launch. You can also manually trigger migration from **Settings → Backup & Restore → Import v1 Data**.

---

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app_shell.dart            # Shell with sidebar + keyboard shortcuts
├── core/                     # Navigator, database, version constants
├── database/                 # SQLite schema, migrations, v1 importer
├── models/                   # Data models (Task, Project, Routine, etc.)
├── providers/                # ChangeNotifier state management
├── repositories/             # Database CRUD operations
├── screens/                  # Dashboard, Tasks, Calendar, Projects, Focus, Routines, Analytics, Settings
├── services/                 # Business logic (TaskService, FocusService, etc.)
├── theme/                    # Colors, typography, dark/light themes
├── widgets/                  # Reusable widgets (TaskCard, Sidebar, TaskDialog, etc.)
└── components/               # Feature-specific components (search, projects, routines, etc.)
```

---

## Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/task_service_test.dart
```

---

## License

This project is proprietary software. All rights reserved.
