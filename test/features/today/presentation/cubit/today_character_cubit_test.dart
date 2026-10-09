// TodayCharacterCubit: what the character says on Today and when, over
// the day's state in fake time: the visit's greeting, the reactions to a
// save, the idle lines, a poke, a profile switch and a new look.

import 'dart:async';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';
import 'package:one_second_diary/features/today/domain/today_lines.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_character_cubit.dart';

import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../support/support.dart';
import '../../support/today_diaries.dart';
import '../../support/today_over_fakes.dart';

void main() {
  late PrefsStore prefs;

  setUp(() async {
    prefs = await openLegacyPrefs(legacyPrefs());
  });

  final LocalDay today = LocalDay(2026, 9, 28);
  final DateTime morning = DateTime(2026, 9, 28, 9);

  /// Runs [body] in fake time from [now] with a character over a
  /// TodayCubit over fakes; [before] scripts the diaries first.
  void withCharacter(
    DateTime now,
    void Function(
      FakeAsync async,
      TodayOverFakes today,
      TodayCharacterCubit character,
    )
    body, {
    void Function(FakeClipRepository clips)? before,
  }) {
    fakeAsync((FakeAsync async) {
      final TodayOverFakes over = TodayOverFakes(
        now: now,
        prefs: prefs,
        before: before,
      );
      final TodayCharacterCubit character = TodayCharacterCubit(
        today: over.cubit,
        settings: over.settings,
        clock: over.clock,
        logger: memoryLogger(over.log),
        random: math.Random(1),
      );
      body(async, over, character);
      unawaited(character.close());
      over.dispose(async);
    });
  }

  void emptyDiary(FakeClipRepository clips) =>
      clips.publish(todayDiary(todayDefault, <LocalDay, int>{}));

  /// A profile that recorded before, so today's first clip is no first
  /// ever.
  void recordedBefore(FakeClipRepository clips) => clips.publish(
    todayDiary(todayDefault, <LocalDay, int>{LocalDay(2026, 9, 20): 1}),
  );

  final List<TodayLine> greetings = <TodayLine>[
    ...TodayLinePools.anyTime,
    TodayLine.goodMorning,
  ];

  /// Lets the character finish its greeting and its bubble go.
  void greet(FakeAsync async, TodayCharacterCubit character) {
    character.shown();
    async.elapse(TodayCharacterCubit.greetingDelay);
    expect(greetings, contains(character.state.line));
    character.lineDone();
  }

  group('arriving', () {
    test('says nothing until shown, then greets after the delay and '
        'remembers the day of the visit', () {
      withCharacter(morning, before: emptyDiary, (async, over, character) {
        async.elapse(const Duration(seconds: 5));
        expect(character.state.line, isNull);

        character.shown();
        expect(character.state.line, isNull);
        async.elapse(TodayCharacterCubit.greetingDelay);

        expect(greetings, contains(character.state.line));
        expect(character.state.lookingDown, isFalse);
        expect(over.settings.todayLastVisit.value, today.epochDay);
      });
    });

    test('with the diary still loading, the greeting waits for it', () {
      withCharacter(morning, (async, over, character) {
        character.shown();
        async.elapse(const Duration(seconds: 3));
        expect(character.state.line, isNull);

        emptyDiary(over.clips);
        async.flushMicrotasks();
        async.elapse(TodayCharacterCubit.greetingDelay);

        expect(greetings, contains(character.state.line));
      });
    });

    test('"Welcome back!" replaces the greeting on the first visit of a day '
        'when the last clip is before yesterday; not after a clip yesterday, '
        'nor in a profile that never recorded', () {
      void visit(
        Map<LocalDay, int> diary, {
        required int lastVisit,
        required Matcher line,
      }) {
        withCharacter(
          morning,
          before: (FakeClipRepository clips) =>
              clips.publish(todayDiary(todayDefault, diary)),
          (async, over, character) {
            unawaited(over.settings.todayLastVisit.set(lastVisit));
            async.flushMicrotasks();

            character.shown();
            async.elapse(TodayCharacterCubit.greetingDelay);

            expect(character.state.line, line);
          },
        );
      }

      visit(
        <LocalDay, int>{LocalDay(2026, 9, 25): 1},
        lastVisit: today.epochDay - 2,
        line: equals(TodayLine.welcomeBack),
      );
      visit(
        <LocalDay, int>{LocalDay(2026, 9, 27): 1},
        lastVisit: today.epochDay - 1,
        line: isIn(greetings),
      );
      visit(
        <LocalDay, int>{},
        lastVisit: today.epochDay - 3,
        line: isIn(greetings),
      );
      visit(
        <LocalDay, int>{LocalDay(2026, 9, 25): 1},
        lastVisit: today.epochDay,
        line: isIn(greetings),
      );
    });
  });

  group('idle lines', () {
    test('come 15 to 25 s after a bubble has gone, from the day\'s pool, '
        'three per visit, then it stays quiet; a save starts them again', () {
      withCharacter(morning, before: recordedBefore, (async, over, character) {
        greet(async, character);

        for (int i = 0; i < TodayLinePools.idlePerVisit; i++) {
          async.elapse(
            TodayCharacterCubit.idleWait - const Duration(seconds: 1),
          );
          expect(character.state.line, isNull, reason: 'idle $i too early');
          async.elapse(
            TodayCharacterCubit.idleWaitSpread + const Duration(seconds: 1),
          );
          expect(TodayLinePools.waiting, contains(character.state.line));
          character.lineDone();
        }
        async.elapse(const Duration(minutes: 2));
        expect(character.state.line, isNull);

        over.saveClipOn(today);
        async.flushMicrotasks();
        expect(TodayLinePools.justSaved, contains(character.state.line));
        character.lineDone();
        async.elapse(
          TodayCharacterCubit.idleWait + TodayCharacterCubit.idleWaitSpread,
        );
        expect(TodayLinePools.keptOne, contains(character.state.line));
      });
    });

    test('none arrives while hidden; shown again within the visit, they go '
        'on', () {
      withCharacter(morning, before: emptyDiary, (async, over, character) {
        greet(async, character);
        character.hidden();
        async.elapse(const Duration(minutes: 1));
        expect(character.state.line, isNull);

        character.shown();
        async.elapse(
          TodayCharacterCubit.idleWait + TodayCharacterCubit.idleWaitSpread,
        );
        expect(TodayLinePools.waiting, contains(character.state.line));
      });
    });
  });

  group('a clip saved', () {
    test('while Today is hidden is said on coming back within the visit, '
        'and in place of the greeting after a longer absence', () {
      withCharacter(morning, before: recordedBefore, (async, over, character) {
        greet(async, character);
        character.hidden();
        over.saveClipOn(today);
        async.flushMicrotasks();
        expect(character.state.line, isNull);

        over.advance(async, const Duration(minutes: 2));
        character.shown();
        expect(TodayLinePools.justSaved, contains(character.state.line));
        character.lineDone();

        character.hidden();
        over.saveClipOn(today);
        async.flushMicrotasks();
        over.advance(async, TodayCharacterCubit.visitGap);
        character.shown();
        expect(character.state.line, TodayLine.manySeconds);
        async.elapse(TodayCharacterCubit.greetingDelay);
        expect(character.state.line, TodayLine.manySeconds);
      });
    });

    test('is the first ever, a milestone, a just-saved line or many '
        'seconds; a clip lost is a deleted line, by what the day has left', () {
      withCharacter(morning, before: emptyDiary, (async, over, character) {
        greet(async, character);

        over.saveClipOn(today);
        async.flushMicrotasks();
        expect(character.state.line, TodayLine.firstClipEver);

        over.saveClipOn(today);
        async.flushMicrotasks();
        expect(character.state.line, TodayLine.manySeconds);

        over.clips.publish(todayDiary(todayDefault, <LocalDay, int>{today: 1}));
        async.flushMicrotasks();
        expect(TodayLinePools.deletedKept, contains(character.state.line));

        over.clips.publish(
          todayDiary(todayDefault, <LocalDay, int>{
            for (int day = 20; day < 26; day++) LocalDay(2026, 9, day): 1,
          }),
        );
        async.flushMicrotasks();
        expect(TodayLinePools.deletedEmpty, contains(character.state.line));

        over.saveClipOn(today);
        async.flushMicrotasks();
        expect(character.state.line, TodayLine.milestone7);
      });
    });
  });

  test('a profile switch says so, never a save reaction', () {
    withCharacter(
      morning,
      before: (FakeClipRepository clips) => clips
        ..publish(todayDiary(todayDefault, <LocalDay, int>{today: 1}))
        ..publish(todayDiary(todayTravel, <LocalDay, int>{today: 2})),
      (async, over, character) {
        greet(async, character);

        unawaited(over.profilesRepository.activate(todayTravel));
        async.flushMicrotasks();

        expect(TodayLinePools.profileSwitched, contains(character.state.line));
      },
    );
  });

  test('a poke answers at once, about the button only while the day has no '
      'clip, looking down at it then', () {
    withCharacter(morning, before: emptyDiary, (async, over, character) {
      greet(async, character);
      const List<TodayLine> waitingPokes = <TodayLine>[
        ...TodayLinePools.poke,
        ...TodayLinePools.pokeWaiting,
      ];
      for (int i = 0; i < 6; i++) {
        character.poke();
        final TodayLine line = character.state.line!;
        expect(waitingPokes, contains(line));
        expect(character.state.lookingDown, line.looksDown);
      }

      over.saveClipOn(today);
      async.flushMicrotasks();
      for (int i = 0; i < 6; i++) {
        character.poke();
        expect(TodayLinePools.poke, contains(character.state.line));
        expect(character.state.lookingDown, isFalse);
      }
    });
  });

  group('a new look', () {
    test('is stored and greeted', () {
      withCharacter(morning, before: emptyDiary, (async, over, character) {
        greet(async, character);
        const CharacterLook round = CharacterLook(shape: CharacterShape.round);

        unawaited(character.customize(round));
        async.flushMicrotasks();

        expect(over.settings.characterLook.value, round);
        expect(character.state.look, round);
        expect(TodayLinePools.customized, contains(character.state.line));
      });
    });

    test('without a character the line goes and nothing is said again: no '
        'idle line, no poke, no greeting on the next visit', () {
      withCharacter(morning, before: emptyDiary, (async, over, character) {
        greet(async, character);
        character.poke();
        expect(character.state.line, isNotNull);
        const CharacterLook none = CharacterLook(hidden: true);

        unawaited(character.customize(none));
        async.flushMicrotasks();

        expect(over.settings.characterLook.value, none);
        expect(character.state.line, isNull);
        character.poke();
        async.elapse(const Duration(minutes: 1));
        expect(character.state.line, isNull);

        character.hidden();
        over.advance(async, TodayCharacterCubit.visitGap);
        character.shown();
        async.elapse(const Duration(minutes: 1));
        expect(character.state.line, isNull);
      });
    });
  });
}
