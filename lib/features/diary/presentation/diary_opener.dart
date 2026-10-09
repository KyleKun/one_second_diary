import 'dart:async';

import 'package:one_second_diary/core/time/local_day.dart';

/// Asks the Diary tab to show this month's calendar, or one day, from
/// elsewhere in the app: the Journey's "This month" and "Days recorded"
/// tiles ask for the month, a place's clips ask for a clip's day, then go
/// to the tab.
///
/// App-scoped (`diary_injection.dart`); the tab's `DiaryCubit` follows it.
/// A Diary tab not built yet needs no asking for the month: it opens on
/// this month's calendar. A day asked for while no Diary listens waits in
/// [takePendingDay] for the cubit that is built next.
final class DiaryOpener {
  final StreamController<void> _requests = StreamController<void>.broadcast();
  final StreamController<LocalDay> _days =
      StreamController<LocalDay>.broadcast();
  LocalDay? _pendingDay;

  /// Each time the Diary is asked to show this month's calendar.
  Stream<void> get requests => _requests.stream;

  /// Each time the Diary is asked to show one day.
  Stream<LocalDay> get dayRequests => _days.stream;

  /// Asks the Diary to show this month's calendar, today (or the month's
  /// default day) selected, whatever month and view it was left on.
  void showThisMonthsCalendar() => _requests.add(null);

  /// Asks the Diary to show [day] in its month's calendar, selected.
  void showDay(LocalDay day) {
    if (_days.hasListener) {
      _days.add(day);
    } else {
      _pendingDay = day;
    }
  }

  /// The day asked for while no Diary was listening, once.
  LocalDay? takePendingDay() {
    final LocalDay? day = _pendingDay;
    _pendingDay = null;
    return day;
  }

  Future<void> dispose() =>
      Future.wait<void>(<Future<void>>[_requests.close(), _days.close()]);
}
