import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/repositories/task_repository.dart';
import 'package:taskflow/services/auto_backup_service.dart';

import '../database/test_helpers.dart';

void main() {
  late Database db;
  late TaskRepository tasks;
  late Directory backupDir;
  late AutoBackupService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    db = await createTestDb();
    AppDatabase.setDatabaseForTesting(db);
    tasks = TaskRepository(db: db);
    backupDir =
        await Directory.systemTemp.createTemp('taskflow_backup_test');
    service = AutoBackupService();
    await service.setFolder(backupDir.path);
    await service.setKeep(3);
  });

  tearDown(() async {
    service.dispose();
    await db.close();
    AppDatabase.closeForTesting();
    try {
      await backupDir.delete(recursive: true);
    } catch (_) {
      // Windows file-lock races in CI — ignore.
    }
  });

  Future<String> createBackupFile() async {
    await tasks.insert(Task(title: 'Ship v2'));
    return service.backupNow();
  }

  /// A backup time two minutes in the past (always due today).
  Future<void> setDueTime({required bool restore}) async {
    final past = DateTime.now().subtract(const Duration(minutes: 2));
    final hhmm = '${past.hour.toString().padLeft(2, '0')}:'
        '${past.minute.toString().padLeft(2, '0')}';
    if (restore) {
      await service.setRestoreTime(hhmm);
    } else {
      await service.setBackupTime(hhmm);
    }
  }

  test('backupNow writes a JSON file and stamps lastBackupAt', () async {
    final path = await createBackupFile();

    expect(File(path).existsSync(), isTrue);
    expect(path.endsWith('.json'), isTrue);
    expect(service.lastBackupAt, isNotNull);
    expect(service.listBackups(), hasLength(1));
  });

  test('restoreNow replaces current data with the backup contents',
      () async {
    final path = await createBackupFile();

    // Mutate data after the backup, then restore.
    await tasks.insert(Task(title: 'Added after backup'));
    expect((await db.query('tasks')).length, 2);

    final result = await service.restoreNow(path: path);

    expect(result, isNotNull);
    expect(result!.rowsImported, greaterThan(0));
    expect(result.wasSafety, isFalse); // Backup was seconds ago.
    final rows = await db.query('tasks');
    expect(rows, hasLength(1));
    expect(rows.first['title'], 'Ship v2');
    expect(service.lastRestoreAt, isNotNull);
    expect(service.lastRestoreSource, isNotNull);
  });

  test('restoreNow takes a safety backup when the last one is stale',
      () async {
    final path = await createBackupFile();

    // Simulate a stale last backup, then reload the service from prefs.
    final stale = DateTime.now().subtract(const Duration(hours: 7));
    await service.setKeep(5); // Room for the safety snapshot.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('autoBackup_lastAt', stale.toIso8601String());

    final fresh = AutoBackupService();
    addTearDown(fresh.dispose);
    await fresh.initialize();
    await fresh.setFolder(backupDir.path);

    final result = await fresh.restoreNow(path: path);
    expect(result!.wasSafety, isTrue);
    // Safety snapshot + original backup.
    expect(fresh.listBackups().length, 2);
  });

  test('tick fires the scheduled backup once per day', () async {
    await tasks.insert(Task(title: 'Tick test'));

    await setDueTime(restore: false);
    await service.tick();
    expect(service.listBackups(), hasLength(1));
    expect(service.nextBackupRun(DateTime.now()), isNotNull);

    // A second tick the same day must not create another backup.
    await service.tick();
    expect(service.listBackups(), hasLength(1));
  });

  test('tick skips backup before the scheduled time', () async {
    await tasks.insert(Task(title: 'Future tick'));

    final now = DateTime.now();
    final inTwoHours =
        '${((now.hour + 2) % 24).toString().padLeft(2, '0')}:00';
    await service.setBackupTime(inTwoHours);

    await service.tick();
    expect(service.listBackups(), isEmpty);
  });

  test('tick skips backup on unselected days', () async {
    await tasks.insert(Task(title: 'Wrong day'));

    final now = DateTime.now();
    final otherDay = now.weekday == 1 ? 2 : 1;
    await service.setBackupDays({otherDay});
    await service.setBackupTime('00:00');

    await service.tick();
    expect(service.listBackups(), isEmpty);
  });

  test('disabled master switch silences the scheduler', () async {
    await tasks.insert(Task(title: 'Disabled'));
    await setDueTime(restore: false);
    await service.setEnabled(false);

    await service.tick();
    expect(service.listBackups(), isEmpty);
  });

  test('scheduled restore replaces data at its slot', () async {
    await tasks.insert(Task(title: 'Restore tick'));
    final path = await service.backupNow();
    expect(path, isNotNull);

    // Data changed after backup.
    await tasks.insert(Task(title: 'Later change'));

    final now = DateTime.now();
    await service.setRestoreEnabled(true);
    await service.setRestoreDays({now.weekday});
    await setDueTime(restore: true);

    await service.tick();

    final rows = await db.query('tasks');
    expect(rows, hasLength(1));
    expect(rows.first['title'], 'Restore tick');
  });

  test('retention prunes old backups beyond the keep limit', () async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await createBackupFile();
    }

    expect(service.listBackups().length, 3); // keep = 3
  });

  test('days helpers round-trip through persistence', () async {
    await service.setBackupDays({2, 4, 6});

    final reloaded = AutoBackupService();
    addTearDown(reloaded.dispose);
    await reloaded.initialize();

    expect(reloaded.backupDays, {2, 4, 6});
  });

  test('backupNow rejects an empty folder with a StateError', () async {
    // Fresh prefs so no folder leaks in from earlier tests.
    SharedPreferences.setMockInitialValues({});
    final bare = AutoBackupService();
    addTearDown(bare.dispose);
    await bare.initialize();

    await expectLater(bare.backupNow(), throwsStateError);
  });

  test('deleteBackup removes a single file', () async {
    final path = await createBackupFile();
    await service.deleteBackup(path);

    expect(File(path).existsSync(), isFalse);
    expect(service.listBackups(), isEmpty);
  });
}
