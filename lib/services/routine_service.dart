import '../models/routine.dart';
import '../repositories/routine_repository.dart';

/// Business rules for routines: the daily reset (streak increments /
/// resets) and completion toggling.
class RoutineService {
  RoutineService({RoutineRepository? routines})
      : _routines = routines ?? RoutineRepository();

  final RoutineRepository _routines;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Applies the "new day" reset to [routine]: clears today's completion
  /// and adjusts the streak (missed a day → streak resets to 0). Persists
  /// only when something changed. Returns the (possibly unchanged) routine.
  Future<Routine> resetForToday(Routine routine, DateTime now) async {
    final today = _day(now);
    final last = routine.lastCompletedDate;
    if (last == null) return routine;

    final lastDay = _day(last);
    final yesterday = today.subtract(const Duration(days: 1));

    if (routine.isCompletedToday) {
      if (lastDay.isBefore(today)) {
        var streak = routine.streak;
        if (lastDay.isBefore(yesterday)) streak = 0;
        final updated = routine.copyWith(isCompletedToday: false, streak: streak);
        await _routines.update(updated);
        return updated;
      }
    } else if (lastDay.isBefore(yesterday) && routine.streak > 0) {
      final updated = routine.copyWith(streak: 0);
      await _routines.update(updated);
      return updated;
    }
    return routine;
  }

  /// Resets every routine in the database against today.
  Future<List<Routine>> resetAll(DateTime now) async {
    final all = await _routines.getAll();
    final updated = <Routine>[];
    for (final routine in all) {
      updated.add(await resetForToday(routine, now));
    }
    return updated;
  }

  /// Toggles today's completion, incrementing (or decrementing) the streak.
  Future<Routine> toggleCompletion(Routine routine) async {
    final Routine updated;
    if (routine.isCompletedToday) {
      updated = routine.copyWith(
        isCompletedToday: false,
        streak: routine.streak > 0 ? routine.streak - 1 : 0,
      );
    } else {
      updated = routine.copyWith(
        isCompletedToday: true,
        streak: routine.streak + 1,
        lastCompletedDate: DateTime.now(),
      );
    }
    await _routines.update(updated);
    return updated;
  }
}
