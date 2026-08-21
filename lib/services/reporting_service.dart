import 'package:csv/csv.dart';

import '../models/subtask.dart';
import '../models/task.dart';
import '../repositories/category_repository.dart';
import '../repositories/subtask_repository.dart';
import '../repositories/task_repository.dart';

/// Shared codec (comma fields, auto-detected line endings).
final Csv _csv = Csv();

/// CSV export/import. Task rows use the v2 column names (a superset of
/// the v1 format, so v1 exports import cleanly); analytics and weekly
/// report exports are single-row summaries for spreadsheets.
class ReportingService {
  ReportingService({
    TaskRepository? tasks,
    CategoryRepository? categories,
    SubtaskRepository? subtasks,
  })  : _tasks = tasks ?? TaskRepository(),
        _categories = categories ?? CategoryRepository(),
        _subtasks = subtasks ?? SubtaskRepository();

  final TaskRepository _tasks;
  final CategoryRepository _categories;
  final SubtaskRepository _subtasks;

  static const List<String> taskColumns = [
    'title',
    'description',
    'category',
    'priority',
    'status',
    'scheduled_date',
    'scheduled_time',
    'due_date',
    'time_spent_seconds',
    'created_at',
    'completed_at',
    'recurrence_rule',
    'subtasks',
    'subtask_states',
  ];

  /// Separator between subtask titles inside the `subtasks` column. Titles
  /// containing this literal sequence are not supported.
  static const String subtaskSeparator = ' | ';

  /// Serializes all active tasks (with their subtasks) to a CSV string.
  Future<String> exportTasksCsv() async {
    final tasks = await _tasks.getAll();
    final rows = <List<Object?>>[taskColumns];
    final categoryNames = <int?, String?>{};
    for (final c in await _categories.getAll()) {
      categoryNames[c.id] = c.name;
    }
    final subtasksByTask =
        await _subtasks.getForTasks([for (final t in tasks) t.id!]);
    for (final t in tasks) {
      final subtasks = subtasksByTask[t.id] ?? const <Subtask>[];
      rows.add([
        t.title,
        t.description,
        categoryNames[t.categoryId] ?? '',
        t.priority,
        t.status,
        t.scheduledDate?.toIso8601String().split('T').first,
        t.scheduledTime,
        t.dueDate?.toIso8601String(),
        t.timeSpentSeconds,
        t.createdAt.toIso8601String(),
        t.completedAt?.toIso8601String(),
        t.recurrenceRule,
        subtasks.map((s) => s.title).join(subtaskSeparator),
        subtasks.map((s) => s.isCompleted ? '1' : '0').join('|'),
      ]);
    }
    return _csv.encode(rows);
  }

  /// Imports tasks from a CSV string, resolving the `category` column by
  /// name. Returns the number of tasks inserted.
  Future<int> importTasksCsv(String csv) async {
    final List<List<dynamic>> rows;
    try {
      rows = _csv.decode(csv);
    } catch (_) {
      return 0;
    }
    if (rows.length < 2) return 0;

    final headers =
        rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
    String cell(List<dynamic> row, String name) {
      final i = headers.indexOf(name);
      if (i < 0 || i >= row.length || row[i] == null) return '';
      return row[i].toString().trim();
    }

    var inserted = 0;
    for (final row in rows.skip(1)) {
      final title = cell(row, 'title');
      if (title.isEmpty) continue;

      final categoryName = cell(row, 'category');
      var categoryId = int.tryParse(cell(row, 'category_id'));
      if (categoryId == null && categoryName.isNotEmpty) {
        final category = await _categories.getByName(categoryName);
        categoryId = category?.id;
      }

      final priority = cell(row, 'priority');
      final status = cell(row, 'status');
      final timeSpent = int.tryParse(cell(row, 'time_spent_seconds'));

      final id = await _tasks.insert(Task(
        title: title,
        description: cell(row, 'description'),
        categoryId: categoryId,
        priority: const ['High', 'Medium', 'Low'].contains(priority)
            ? priority
            : 'Medium',
        status: const ['Pending', 'In Progress', 'Completed'].contains(status)
            ? status
            : 'Pending',
        scheduledDate: _parseDate(cell(row, 'scheduled_date')),
        scheduledTime:
            cell(row, 'scheduled_time').isEmpty ? null : cell(row, 'scheduled_time'),
        dueDate: _parseDateTime(cell(row, 'due_date')),
        timeSpentSeconds: timeSpent ?? 0,
        completedAt: _parseDateTime(cell(row, 'completed_at')),
        recurrenceRule:
            cell(row, 'recurrence_rule').isEmpty ? null : cell(row, 'recurrence_rule'),
      ));

      // Subtasks: `subtasks` is `Title A | Title B`, `subtask_states` is
      // `1|0` aligned by index (missing states default to incomplete).
      final subtaskTitles = cell(row, 'subtasks');
      if (subtaskTitles.isNotEmpty) {
        final titles = subtaskTitles.split(subtaskSeparator);
        final states = cell(row, 'subtask_states').split('|');
        for (var i = 0; i < titles.length; i++) {
          final done = i < states.length && states[i].trim() == '1';
          await _subtasks.insert(Subtask(
            taskId: id,
            title: titles[i].trim(),
            isCompleted: done,
            sortOrder: i,
          ));
        }
      }
      inserted++;
    }
    return inserted;
  }

  /// One-row analytics summary CSV (opens cleanly in Excel).
  Future<String> exportAnalyticsCsv(Map<String, Object> metrics) {
    final rows = [
      [for (final key in metrics.keys) key],
      [for (final value in metrics.values) value],
    ];
    return Future.value(_csv.encode(rows));
  }

  /// One-row weekly report CSV.
  Future<String> exportWeeklyReportCsv(Map<String, Object> report) {
    final rows = [
      [for (final key in report.keys) key],
      [for (final value in report.values) value],
    ];
    return Future.value(_csv.encode(rows));
  }

  static DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;
    final date = DateTime.tryParse(value);
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime? _parseDateTime(String value) {
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
