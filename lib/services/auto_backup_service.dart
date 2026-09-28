import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_change_notifier.dart';
import '../core/event_bus.dart';
import 'backup_service.dart';
import 'notification_service.dart';
import 'ui_sound_service.dart';

/// A single automatic backup file on disk.
class AutoBackupFile {
  const AutoBackupFile({
    required this.path,
    required this.modified,
    required this.sizeBytes,
  });

  final String path;
  final DateTime modified;
  final int sizeBytes;

  String get name => p.basename(path);

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Result of a restore operation, for toasts and the status card.
class AutoRestoreResult {
  const AutoRestoreResult({
    required this.rowsImported,
    required this.backupName,
    this.wasSafety,
  });

  final int rowsImported;
  final String backupName;

  /// Whether a safety backup was taken before restoring.
  final bool? wasSafety;
}

/// Owns the automatic backup & restore feature.
///
/// The scheduler runs while the app is open: a periodic timer compares the
/// clock with the backup/restore schedule and fires each one at most once
/// per scheduled day. Backup and restore settings are persisted in
/// [SharedPreferences]; backup files are written as JSON into a
/// user-selected folder.
class AutoBackupService extends AppChangeNotifier {
  AutoBackupService({BackupService? backup, NotificationService? notifications})
      : _backup = backup ?? BackupService(),
        _notifications = notifications ?? NotificationService(toasts: false);

  final BackupService _backup;
  final NotificationService _notifications;

  // ─── Preference keys ───
  static const _kEnabled = 'autoBackup_enabled';
  static const _kRestoreEnabled = 'autoRestore_enabled';
  static const _kBackupTime = 'autoBackup_time'; // 'HH:mm'
  static const _kRestoreTime = 'autoRestore_time'; // 'HH:mm'
  static const _kBackupDays = 'autoBackup_days'; // csv of weekday ints
  static const _kRestoreDays = 'autoRestore_days'; // csv of weekday ints
  static const _kFolder = 'autoBackup_folder';
  static const _kRetention = 'autoBackup_keep';
  static const _kLastBackup = 'autoBackup_lastAt';
  static const _kLastRestore = 'autoRestore_lastAt';
  static const _kLastRestoreSource = 'autoRestore_lastSource';
  static const _kBackupFired = 'autoBackup_firedOn'; // yyyy-MM-dd
  static const _kRestoreFired = 'autoRestore_firedOn'; // yyyy-MM-dd

  // ─── Defaults ───
  static const String defaultFolderName = 'TaskFlow Backups';

  // ─── State ───
  bool _enabled = true;
  bool _restoreEnabled = false;
  int _backupHour = 20;
  int _backupMinute = 0;
  int _restoreHour = 8;
  int _restoreMinute = 0;
  Set<int> _backupDays = {1, 2, 3, 4, 5, 6, 7};
  Set<int> _restoreDays = {1, 2, 3, 4, 5, 6, 7};
  String _folder = '';
  int _keep = 30;
  DateTime? _lastBackupAt;
  DateTime? _lastRestoreAt;
  String? _lastRestoreSource;
  String? _backupFiredOn;
  String? _restoreFiredOn;

  bool get enabled => _enabled;
  bool get restoreEnabled => _restoreEnabled;
  String get backupTimeLabel => '${_two(_backupHour)}:${_two(_backupMinute)}';
  String get restoreTimeLabel => '${_two(_restoreHour)}:${_two(_restoreMinute)}';
  Set<int> get backupDays => Set.unmodifiable(_backupDays);
  Set<int> get restoreDays => Set.unmodifiable(_restoreDays);
  String get folder => _folder;
  int get keep => _keep;
  DateTime? get lastBackupAt => _lastBackupAt;
  DateTime? get lastRestoreAt => _lastRestoreAt;
  String? get lastRestoreSource => _lastRestoreSource;

  bool get folderReady => _folder.trim().isNotEmpty && Directory(_folder).existsSync();

  /// True when backup/restore scheduling is armed (master on + folder set).
  bool get isArmed => _enabled && folderReady;

  /// The next moment the backup is scheduled to run (null if disarmed).
  DateTime? nextBackupRun(DateTime now) =>
      _enabled && _backupDays.isNotEmpty ? _nextRun(now, _backupHour, _backupMinute, _backupDays) : null;

  /// The next moment the restore is scheduled to run (null if disarmed).
  DateTime? nextRestoreRun(DateTime now) => _restoreEnabled && _restoreDays.isNotEmpty
      ? _nextRun(now, _restoreHour, _restoreMinute, _restoreDays)
      : null;

  // ─── Init / persistence ───

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabled) ?? true;
    _restoreEnabled = prefs.getBool(_kRestoreEnabled) ?? false;
    final bt = prefs.getString(_kBackupTime)?.split(':');
    if (bt != null && bt.length == 2) {
      _backupHour = int.tryParse(bt[0]) ?? 20;
      _backupMinute = int.tryParse(bt[1]) ?? 0;
    }
    final rt = prefs.getString(_kRestoreTime)?.split(':');
    if (rt != null && rt.length == 2) {
      _restoreHour = int.tryParse(rt[0]) ?? 8;
      _restoreMinute = int.tryParse(rt[1]) ?? 0;
    }
    _backupDays = _decodeDays(prefs.getString(_kBackupDays), defaultDays: _backupDays);
    _restoreDays = _decodeDays(prefs.getString(_kRestoreDays), defaultDays: _restoreDays);
    _folder = prefs.getString(_kFolder) ?? '';
    _keep = prefs.getInt(_kRetention) ?? 30;
    _lastBackupAt = _parseDate(prefs.getString(_kLastBackup));
    _lastRestoreAt = _parseDate(prefs.getString(_kLastRestore));
    _lastRestoreSource = prefs.getString(_kLastRestoreSource);
    _backupFiredOn = prefs.getString(_kBackupFired);
    _restoreFiredOn = prefs.getString(_kRestoreFired);
    safeNotify();
  }

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    safeNotify();
    (await _prefs()).setBool(_kEnabled, value);
  }

  Future<void> setRestoreEnabled(bool value) async {
    _restoreEnabled = value;
    safeNotify();
    (await _prefs()).setBool(_kRestoreEnabled, value);
  }

  /// Sets the backup time from a 'HH:mm' string (e.g. from showTimePicker).
  Future<void> setBackupTime(String hhmm) async {
    final parts = hhmm.split(':');
    if (parts.length != 2) return;
    _backupHour = (int.tryParse(parts[0]) ?? 20).clamp(0, 23);
    _backupMinute = (int.tryParse(parts[1]) ?? 0).clamp(0, 59);
    safeNotify();
    (await _prefs()).setString(_kBackupTime, backupTimeLabel);
  }

  Future<void> setRestoreTime(String hhmm) async {
    final parts = hhmm.split(':');
    if (parts.length != 2) return;
    _restoreHour = (int.tryParse(parts[0]) ?? 8).clamp(0, 23);
    _restoreMinute = (int.tryParse(parts[1]) ?? 0).clamp(0, 59);
    safeNotify();
    (await _prefs()).setString(_kRestoreTime, restoreTimeLabel);
  }

  Future<void> setBackupDays(Set<int> days) async {
    _backupDays = days.isEmpty ? {DateTime.now().weekday} : Set.of(days);
    safeNotify();
    (await _prefs()).setString(_kBackupDays, _encodeDays(_backupDays));
  }

  Future<void> setRestoreDays(Set<int> days) async {
    _restoreDays = days.isEmpty ? {DateTime.now().weekday} : Set.of(days);
    safeNotify();
    (await _prefs()).setString(_kRestoreDays, _encodeDays(_restoreDays));
  }

  Future<void> setFolder(String folder) async {
    _folder = folder.trim();
    safeNotify();
    (await _prefs()).setString(_kFolder, _folder);
  }

  Future<void> setKeep(int value) async {
    _keep = value.clamp(1, 365);
    safeNotify();
    (await _prefs()).setInt(_kRetention, _keep);
  }

  // ─── History ───

  /// All automatic backup files in the selected folder, newest first.
  List<AutoBackupFile> listBackups() {
    if (_folder.isEmpty) return const [];
    final dir = Directory(_folder);
    if (!dir.existsSync()) return const [];
    final files = <AutoBackupFile>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      if (!p.basename(entity.path).startsWith(_fileNamePrefix)) continue;
      if (!entity.path.toLowerCase().endsWith('.json')) continue;
      final stat = entity.statSync();
      files.add(AutoBackupFile(
        path: entity.path,
        modified: stat.modified,
        sizeBytes: stat.size,
      ));
    }
    files.sort((a, b) => b.modified.compareTo(a.modified));
    return files;
  }

  /// Reads and validates the JSON of the newest backup, or null.
  Future<String?> latestBackupJson() async {
    final files = listBackups();
    if (files.isEmpty) return null;
    final raw = await File(files.first.path).readAsString();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['schemaVersion'] != null) return raw;
    } catch (_) {
      // Corrupt file — fall through.
    }
    return null;
  }

  // ─── Manual + automatic execution ───

  /// Creates a backup now in the selected folder. Returns the file path.
  Future<String> backupNow({bool automatic = false}) async {
    final dir = _folder.trim();
    if (dir.isEmpty) {
      throw StateError('No backup folder selected');
    }
    await Directory(dir).create(recursive: true);
    final json = await _backup.exportJson();
    final stamp = _stamp(DateTime.now());
    final file = File(p.join(dir, '$_fileNamePrefix$stamp.json'));
    await file.writeAsString(json, flush: true);
    _lastBackupAt = DateTime.now();
    final prefs = await _prefs();
    await prefs.setString(_kLastBackup, _lastBackupAt!.toIso8601String());
    await prefs.setString(_kBackupFired, _dayKey(_lastBackupAt!));
    _backupFiredOn = _dayKey(_lastBackupAt!);
    await pruneOldBackups();
    safeNotify();
    UiSoundService.instance.play(UiSoundCue.send);
    if (automatic) {
      await _notifications.showToast(
        title: '💾 Backup created',
        body: 'Your TaskFlow data was automatically backed up.',
      );
    }
    return file.path;
  }

  /// Restores the newest backup (or [path]) now. Takes a safety backup
  /// first (unless one was already taken in the last 6 hours) and refreshes
  /// cached provider data. Returns the restore result.
  Future<AutoRestoreResult?> restoreNow({String? path, bool automatic = false}) async {
    final target = path ?? await latestBackupJson();
    String? json;
    String name;
    if (path != null) {
      json = await File(path).readAsString();
      name = p.basename(path);
    } else if (target != null) {
      json = target;
      name = p.basename(listBackups().first.path);
    } else {
      return null;
    }

    // Validate before touching data: a corrupt or foreign file must
    // never wipe the database (importJson(replace) clears tables first).
    final preview = await _backup.preview(json);
    final known = preview.keys.where(_knownTables.contains).toSet();
    if (known.isEmpty) {
      throw StateError('"$name" is not a valid TaskFlow backup file');
    }

    // Safety backup before replacing data (best effort).
    var safety = false;
    if (_folder.trim().isNotEmpty && !_hadRecentSafetyBackup()) {
      try {
        await backupNow();
        safety = true;
      } catch (_) {
        // Never block a restore because the safety snapshot failed.
      }
    }

    final imported = await _backup.importJson(json, merge: false);
    final rows = imported.values.fold<int>(0, (a, b) => a + b);

    _lastRestoreAt = DateTime.now();
    _lastRestoreSource = name;
    final prefs = await _prefs();
    await prefs.setString(_kLastRestore, _lastRestoreAt!.toIso8601String());
    await prefs.setString(_kLastRestoreSource, name);
    await prefs.setString(_kRestoreFired, _dayKey(_lastRestoreAt!));
    _restoreFiredOn = _dayKey(_lastRestoreAt!);

    // Refresh every data surface (tasks, calendar, analytics, ...).
    EventBus.instance.emit(AppEvent.dataReset);

    safeNotify();
    UiSoundService.instance.play(UiSoundCue.success);
    if (automatic) {
      await _notifications.showToast(
        title: '♻️ Data restored',
        body: '$rows rows were restored from "$name".',
      );
    }
    return AutoRestoreResult(
      rowsImported: rows,
      backupName: name,
      wasSafety: safety,
    );
  }

  /// Deletes backup files beyond the retention limit. Returns removed count.
  Future<int> pruneOldBackups() async {
    final files = listBackups();
    var removed = 0;
    for (var i = _keep; i < files.length; i++) {
      try {
        await File(files[i].path).delete();
        removed++;
      } catch (_) {
        // In-use or locked file — try again next time.
      }
    }
    return removed;
  }

  /// Deletes a single backup file.
  Future<void> deleteBackup(String path) async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }

  // ─── Scheduler ───

  Timer? _timer;
  bool _busy = false;

  /// Starts the periodic check (call once from the app shell).
  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One scheduler pass: fires the backup and/or restore when due.
  Future<void> tick() async {
    if (_busy) return;
    if (!_enabled) return;
    final now = DateTime.now();
    final today = _dayKey(now);

    // ── Scheduled restore ──
    if (_restoreEnabled &&
        _restoreDays.contains(now.weekday) &&
        _restoreFiredOn != today &&
        !_isTimeBefore(now, _restoreHour, _restoreMinute) &&
        folderReady) {
      _busy = true;
      try {
        await restoreNow(automatic: true);
      } catch (e) {
        debugPrint('AutoBackupService restore error: $e');
      } finally {
        _busy = false;
      }
      return; // One job per tick.
    }

    // ── Scheduled backup ──
    if (_backupDays.contains(now.weekday) &&
        _backupFiredOn != today &&
        !_isTimeBefore(now, _backupHour, _backupMinute) &&
        folderReady) {
      _busy = true;
      try {
        await backupNow(automatic: true);
      } catch (e) {
        debugPrint('AutoBackupService backup error: $e');
      } finally {
        _busy = false;
      }
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  // ─── Helpers ───

  static const _fileNamePrefix = 'taskflow_auto_backup_';

  /// Tables that identify a file as a TaskFlow JSON backup.
  static const _knownTables = <String>{
    'categories', 'tags', 'projects', 'tasks', 'subtasks',
    'project_statuses', 'routines', 'focus_sessions', 'task_tags',
  };

  bool _hadRecentSafetyBackup() {
    final last = _lastBackupAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < const Duration(hours: 6);
  }

  /// Millisecond precision prevents a fast-follow backup (e.g. the safety
  /// snapshot taken right before a restore) from overwriting the file it
  /// was created next to.
  static String _stamp(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}${_two(t.month)}${_two(t.day)}'
      '_${_two(t.hour)}${_two(t.minute)}${_two(t.second)}'
      '${t.millisecond.toString().padLeft(3, '0')}';

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static DateTime? _parseDate(String? iso) {
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  static bool _isTimeBefore(DateTime now, int hour, int minute) {
    final nowMinutes = now.hour * 60 + now.minute;
    final target = hour * 60 + minute;
    return nowMinutes < target;
  }

  static String _encodeDays(Set<int> days) =>
      days.map((d) => d.toString()).toList().join(',');

  static Set<int> _decodeDays(String? csv, {required Set<int> defaultDays}) {
    if (csv == null || csv.isEmpty) return Set.of(defaultDays);
    final days = <int>{};
    for (final part in csv.split(',')) {
      final v = int.tryParse(part.trim());
      if (v != null && v >= 1 && v <= 7) days.add(v);
    }
    return days;
  }

  /// The next datetime matching [days] at [hour]:[minute] (may be [now]'s
  /// slot if that hasn't passed yet).
  static DateTime _nextRun(DateTime now, int hour, int minute, Set<int> days) {
    for (var offset = 0; offset < 8; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      if (!days.contains(day.weekday)) continue;
      final run = DateTime(now.year, now.month, now.day + offset, hour, minute);
      if (run.isAfter(now)) return run;
    }
    return now; // Unreachable for non-empty day sets.
  }
}
