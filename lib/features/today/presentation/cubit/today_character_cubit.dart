import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/today/domain/today_lines.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_character_state.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_cubit.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_state.dart';

export 'package:one_second_diary/features/today/presentation/cubit/today_character_state.dart';

/// What the character says on Today, and when, for as long as the tab
/// lives. One line at a time; the page shows it in the bubble and says
/// when it has gone ([lineDone]).
///
/// - A visit starts when Today is [shown] after being hidden for
///   [visitGap] (the app opened, a tab shown after a while) or when the
///   day changes. Once the diary is read it greets: "Welcome back!" on the
///   first visit of a day after a missed one, else half the time a hello
///   and half the time the part of the day's greeting.
/// - A clip saved to the day is a reaction on coming back: the day's first
///   clip is the profile's first ever, a milestone of recorded days, or a
///   "just saved" line; another clip is "Many seconds today!". One lost
///   (deleted, undone) has its own lines, by whether the day has any left,
///   and restarts the idle lines in the new state.
/// - Idle lines come 15 to 25 seconds after a bubble has gone, at most
///   [TodayLinePools.idlePerVisit] per visit (a save starts them again),
///   never while Today is hidden; each pool rotates without repeats.
/// - A profile switch, a poke and a new look from the sheet each have
///   their lines. Without a character ([CharacterLook.hidden]) it says
///   nothing and no timer runs.
///
/// Lines that come while Today is hidden wait for it to show: the one
/// waiting replaces the visit's greeting.
class TodayCharacterCubit extends Cubit<TodayCharacterState> {
  TodayCharacterCubit({
    required TodayCubit today,
    required SettingsRepository settings,
    required this._clock,
    required this._logger,
    math.Random? random,
  }) : _today = today,
       _settings = settings,
       _random = random ?? math.Random(),
       _last = today.state,
       super(TodayCharacterState(look: settings.characterLook.value)) {
    _rotation = TodayLineRotation(_random);
    _todayChanges = today.stream.listen(_todayChanged);
    _lookChanges = settings.characterLook.changes.listen((CharacterLook look) {
      if (look != state.look) emit(state.withLook(look));
    });
  }

  /// Hidden this long, Today is a new visit when it shows again.
  static const Duration visitGap = Duration(minutes: 15);

  /// The greeting waits this long after Today shows.
  static const Duration greetingDelay = Duration(milliseconds: 500);

  /// The least and the extra wait before an idle line.
  static const Duration idleWait = Duration(seconds: 15);
  static const Duration idleWaitSpread = Duration(seconds: 10);

  static const String _tag = 'TODAY';

  final TodayCubit _today;
  final SettingsRepository _settings;
  final Clock _clock;
  final AppLogger _logger;
  final math.Random _random;
  late final TodayLineRotation _rotation;
  late final StreamSubscription<TodayState> _todayChanges;
  late final StreamSubscription<CharacterLook> _lookChanges;

  TodayState _last;
  bool _visible = false;
  DateTime? _hiddenAt;

  /// The visit's greeting has been said, or is on its way.
  bool _greeted = false;

  /// The greeting's timer is running: hidden meanwhile, the visit greets
  /// again when it shows.
  bool _greetingPending = false;
  int _idleSaid = 0;

  /// A line that came while Today was hidden.
  TodayLine? _pending;
  Timer? _next;

  /// Today is on screen: a new visit after [visitGap], else the line that
  /// waited, else the idle lines go on.
  void shown() {
    if (_visible) return;
    _visible = true;
    final DateTime? hiddenAt = _hiddenAt;
    if (hiddenAt == null || _clock.now().difference(hiddenAt) >= visitGap) {
      _startVisit();
    } else if (!_greeted) {
      _arrive();
    } else if (_pending != null) {
      _say(_pending!);
    } else if (state.line == null) {
      _scheduleIdle();
    }
  }

  /// Today left the screen (another tab, a page over it, the app in the
  /// background): nothing is said until it is back.
  void hidden() {
    if (!_visible) return;
    _visible = false;
    _hiddenAt = _clock.now();
    _next?.cancel();
    if (_greetingPending) {
      _greetingPending = false;
      _greeted = false;
    }
  }

  /// The bubble has gone.
  void lineDone() {
    if (state.line == null) return;
    emit(state.withLine(null));
    _scheduleIdle();
  }

  /// A tap on the character.
  void poke() {
    if (state.look.hidden) return;
    final bool waiting = _today.state.clips.isEmpty;
    _say(
      waiting && _random.nextBool()
          ? _rotation.next(TodayLinePools.pokeWaiting)
          : _rotation.next(TodayLinePools.poke),
    );
  }

  /// The sheet closed with [look]: kept, and the character says so. When
  /// the phone refuses to store it, the look stays as it was.
  Future<void> customize(CharacterLook look) async {
    if (look == state.look) return;
    try {
      await _settings.characterLook.set(look);
    } on StorageException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not store the character look',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    _logger.info(_tag, look.hidden ? 'Character hidden' : 'Character look set');
    if (look.hidden) {
      _next?.cancel();
      _pending = null;
      emit(TodayCharacterState(look: look, lineId: state.lineId + 1));
      return;
    }
    emit(state.withLook(look));
    _say(_rotation.next(TodayLinePools.customized));
  }

  void _todayChanged(TodayState next) {
    final TodayState before = _last;
    _last = next;
    if (state.look.hidden) return;
    if (next.profile.key != before.profile.key) {
      _idleSaid = 0;
      _queue(_rotation.next(TodayLinePools.profileSwitched));
    } else if (next.day != before.day) {
      _startVisit();
    } else if (before.status == TodayStatus.ready &&
        next.status == TodayStatus.ready &&
        next.clips.length != before.clips.length) {
      _idleSaid = 0;
      _queue(_reactionTo(before, next));
    }
    if (!_greeted) _arrive();
  }

  /// The line for the day going from [before]'s clips to [next]'s.
  TodayLine _reactionTo(TodayState before, TodayState next) {
    final int count = next.clips.length;
    if (count < before.clips.length) {
      return _rotation.next(TodayLinePools.deleted(count));
    }
    if (count > 1 || before.clips.isNotEmpty) return TodayLine.manySeconds;
    if (next.recordedDays > before.recordedDays) {
      if (next.recordedDays == 1) return TodayLine.firstClipEver;
      final TodayLine? milestone = TodayLinePools.milestone(next.recordedDays);
      if (milestone != null) return milestone;
    }
    return _rotation.next(TodayLinePools.justSaved);
  }

  void _startVisit() {
    _idleSaid = 0;
    _greeted = false;
    _greetingPending = false;
    _next?.cancel();
    _arrive();
  }

  /// The visit's greeting, once Today is on screen with its diary read.
  void _arrive() {
    if (_greeted || !_visible || state.look.hidden) return;
    final TodayState today = _today.state;
    if (today.status == TodayStatus.loading) return;
    _greeted = true;
    final int? lastVisit = _settings.todayLastVisit.value;
    _rememberVisit(today.day.epochDay);
    final TodayLine? pending = _pending;
    if (pending != null) {
      _say(pending);
      return;
    }
    final TodayLine greeting = _missedADay(today, lastVisit)
        ? TodayLine.welcomeBack
        : _random.nextBool()
        ? _rotation.next(TodayLinePools.anyTime)
        : TodayLinePools.partOfDay(today.partOfDay);
    _next?.cancel();
    _greetingPending = true;
    _next = Timer(greetingDelay, () {
      _greetingPending = false;
      _say(greeting);
    });
  }

  /// The first visit of a day, with no clip since before yesterday in a
  /// profile that has recorded before.
  static bool _missedADay(TodayState today, int? lastVisit) {
    final LocalDay? last = today.lastRecordedDay;
    return lastVisit != null &&
        lastVisit < today.day.epochDay &&
        last != null &&
        last.epochDay < today.day.epochDay - 1;
  }

  void _rememberVisit(int epochDay) {
    if (_settings.todayLastVisit.value == epochDay) return;
    unawaited(
      _settings.todayLastVisit.set(epochDay).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        _logger.error(
          _tag,
          'Could not store the visit day',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  void _queue(TodayLine line) {
    if (_visible) {
      _say(line);
    } else {
      _pending = line;
    }
  }

  void _say(TodayLine line) {
    _next?.cancel();
    _pending = null;
    emit(state.withLine(line));
  }

  /// An idle line in 15 to 25 seconds, until the visit has heard its
  /// share.
  void _scheduleIdle() {
    _next?.cancel();
    if (!_visible || state.look.hidden) return;
    if (_idleSaid >= TodayLinePools.idlePerVisit) return;
    _next = Timer(idleWait + idleWaitSpread * _random.nextDouble(), () {
      _idleSaid++;
      _say(_rotation.next(TodayLinePools.idle(_today.state.clips.length)));
    });
  }

  @override
  Future<void> close() async {
    _next?.cancel();
    await _todayChanges.cancel();
    await _lookChanges.cancel();
    return super.close();
  }
}
