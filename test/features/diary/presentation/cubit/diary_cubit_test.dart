import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/data/clip_captions.dart';
import 'package:one_second_diary/features/diary/data/clip_filtering.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_day.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_opener.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';
import '../../support/diary_fixtures.dart';
import '../../support/fake_clip_store.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

/// Monday, September 28, 2026, 22:50.
final DateTime _now = DateTime(2026, 9, 28, 22, 50);

LocalDay sep(int day) => LocalDay(2026, 9, day);

/// September: every day through the 28th but the 9th, 21st and 25th.
final List<LocalDay> d1Days = <LocalDay>[
  for (int day = 1; day <= 28; day++)
    if (day != 9 && day != 21 && day != 25) sep(day),
];

void main() {
  late FakeClock clock;
  late FakeProfilesRepository profiles;
  late _RescannableClips clips;
  late SettingsRepository settings;
  late ClipMetadataCache metadata;
  late FakeClipStore store;
  late FakeShareGateway share;
  late DiaryOpener opener;
  final AppPaths paths = AppPaths.forTest(Directory('/osd'));
  final List<DiaryCubit> made = <DiaryCubit>[];

  setUp(() async {
    clock = FakeClock(_now);
    profiles = FakeProfilesRepository();
    clips = _RescannableClips();
    store = FakeClipStore(clips);
    share = FakeShareGateway();
    opener = DiaryOpener();
    settings = SettingsRepository(prefs: await openLegacyPrefs(legacyPrefs()));
    metadata = ClipMetadataCache(
      paths: AppPaths.forTest(Directory('/osd')),
      logger: memoryLogger(MemoryLogSink()),
    );
  });

  tearDown(() async {
    for (final DiaryCubit subject in made) {
      await subject.close();
    }
    made.clear();
    await profiles.close();
    await clips.close();
    await opener.dispose();
  });

  DiaryCubit cubit() {
    final DiaryCubit subject = DiaryCubit(
      profiles: profiles,
      clips: clips,
      settings: settings,
      midnight: MidnightTicker(clock: clock),
      captions: ClipCaptions(clips: clips, metadata: metadata),
      filtering: ClipFiltering(metadata: metadata),
      store: store,
      share: share,
      opener: opener,
      paths: paths,
      logger: memoryLogger(MemoryLogSink()),
    );
    made.add(subject);
    return subject;
  }

  group('opening', () {
    test('shows this month from the index in memory at once, on its default '
        'day: today when recorded, else the latest recorded day, else '
        'today', () {
      for (final (List<LocalDay> days, LocalDay selected)
          in <(List<LocalDay>, LocalDay)>[
            (d1Days, sep(28)),
            (<LocalDay>[sep(3), sep(20)], sep(20)),
            (<LocalDay>[LocalDay(2026, 8, 2)], sep(28)),
          ]) {
        clips.publish(clipIndexOf(_default, days));

        final DiaryState state = cubit().state;

        expect(state.status, DiaryStatus.ready);
        expect(state.today, sep(28));
        expect(state.month, const DiaryMonth(2026, 9));
        expect(state.selected, selected, reason: '$days');
      }
    });

    test('a diary read after the tab opened selects the default day', () async {
      final DiaryCubit subject = cubit();
      expect(subject.state.status, DiaryStatus.loading);

      clips.publish(clipIndexOf(_default, <LocalDay>[sep(3), sep(20)]));
      await pumpEventQueue();

      expect(subject.state.status, DiaryStatus.ready);
      expect(subject.state.selected, sep(20));
    });
  });

  test('"N of M days" counts recorded days, never clips (D1), leaves out '
      'the days before the first clip, and is unknown until read', () {
    expect(cubit().state.monthCount, isNull);

    clips.publish(clipIndexOf(_default, d1Days));
    expect(cubit().state.monthCount, (recorded: 25, total: 28));

    clips.publish(
      diaryIndex(_default, <LocalDay, int>{
        LocalDay(2026, 7, 30): 1,
        LocalDay(2026, 8, 30): 1,
        sep(1): 3,
        sep(2): 1,
      }),
    );
    final DiaryState state = cubit().state;
    expect(state.monthCount, (recorded: 2, total: 28));
    // Any month's count (the Memories headers).
    expect(state.monthCountOf(const DiaryMonth(2026, 7)), (
      recorded: 1,
      total: 2,
    ));

    // The days before the first clip are neither missed nor counted.
    clips.publish(clipIndexOf(_default, <LocalDay>[sep(10), sep(12)]));
    expect(cubit().state.monthCount, (recorded: 2, total: 19));
  });

  test('a recorded day of the grid shows its first clip and how many it '
      'has, and says when it is selected', () {
    clips.publish(
      diaryIndex(_default, <LocalDay, int>{sep(1): 1, sep(16): 3, sep(28): 1}),
    );
    final DiaryState state = cubit().state;

    final DiaryDay day = state.dayOf(sep(16));

    expect(day.kind, DiaryDayKind.recorded);
    expect(day.clip, diaryClip(_default, sep(16)));
    expect(day.stamp, diaryStamp);
    expect(day.clipCount, 3);
    expect(day.isToday, isFalse);
    expect(day.isSelected, isFalse);
    expect(state.dayOf(sep(28)).isSelected, isTrue);
  });

  test("a day before the profile's first clip is neither missed nor "
      'recorded (Q-D3); a later day without a clip is missed, today too, '
      'and a day to come is future', () {
    // Before the diary is read, past days are unknown.
    final DiaryState unread = cubit().state;
    expect(unread.dayOf(sep(3)).kind, DiaryDayKind.unknown);
    expect(unread.dayOf(sep(29)).kind, DiaryDayKind.future);

    clips.publish(clipIndexOf(_default, <LocalDay>[sep(10)]));
    final DiaryState state = cubit().state;
    for (final (LocalDay day, DiaryDayKind kind) in <(LocalDay, DiaryDayKind)>[
      (sep(9), DiaryDayKind.beforeFirstClip),
      (sep(11), DiaryDayKind.missed),
      (sep(28), DiaryDayKind.missed),
      (sep(29), DiaryDayKind.future),
    ]) {
      expect(state.dayOf(day).kind, kind, reason: '$day');
      expect(state.dayOf(day).clip, isNull);
    }
    expect(state.dayOf(sep(28)).isToday, isTrue);

    clips.publish(clipIndexOf(_default, <LocalDay>[]));
    expect(cubit().state.dayOf(sep(28)).kind, DiaryDayKind.beforeFirstClip);
  });

  group('months', () {
    test('the previous month opens on its latest recorded day, an empty one '
        'on none; this month comes back with its default day', () {
      clips.publish(
        clipIndexOf(_default, <LocalDay>[
          LocalDay(2026, 6, 3),
          LocalDay(2026, 8, 3),
          LocalDay(2026, 8, 17),
          sep(2),
          sep(28),
        ]),
      );
      final DiaryCubit subject = cubit()..showPreviousMonth();
      expect(subject.state.month, const DiaryMonth(2026, 8));
      expect(subject.state.selected, LocalDay(2026, 8, 17));

      subject.showPreviousMonth();
      expect(subject.state.month, const DiaryMonth(2026, 7));
      expect(subject.state.selected, isNull);
      expect(subject.state.selectedClips, isEmpty);

      subject.showThisMonth();
      expect(subject.state.month, const DiaryMonth(2026, 9));
      expect(subject.state.selected, sep(28));
    });

    test('there is no month after this one', () async {
      clips.publish(clipIndexOf(_default, d1Days));
      final DiaryCubit subject = cubit();

      expect(subject.state.canShowNext, isFalse);
      subject.showNextMonth();
      expect(subject.state.month, const DiaryMonth(2026, 9));

      subject.showPreviousMonth();
      expect(subject.state.canShowNext, isTrue);
      subject.showNextMonth();
      expect(subject.state.month, const DiaryMonth(2026, 9));
      expect(subject.state.selected, sep(28));
    });

    test('history goes back to January 2018 (Q-D2), so old footage can be '
        'imported', () async {
      clips.publish(clipIndexOf(_default, d1Days));
      final DiaryCubit subject = cubit();
      const int months = (2026 - 2018) * 12 + 8;
      for (int i = 0; i < months + 5; i++) {
        subject.showPreviousMonth();
      }

      expect(subject.state.month, const DiaryMonth(2018, 1));
      expect(subject.state.canShowPrevious, isFalse);
    });

    test('a clip older than 2018 extends the history to its month', () async {
      clips.publish(
        clipIndexOf(_default, <LocalDay>[LocalDay(2015, 7, 4), sep(1)]),
      );
      final DiaryCubit subject = cubit();
      while (subject.state.canShowPrevious) {
        subject.showPreviousMonth();
      }

      expect(subject.state.month, const DiaryMonth(2015, 7));
      expect(subject.state.selected, LocalDay(2015, 7, 4));
    });
  });

  test("the selected day's clips are every clip of the day, in recording "
      'order (D1), and none for a missed day', () {
    clips.publish(
      diaryIndex(_default, <LocalDay, int>{sep(1): 1, sep(16): 3, sep(28): 1}),
    );
    final DiaryCubit subject = cubit()..selectDay(sep(16));

    expect(subject.state.selectedClips, <ClipRef>[
      diaryClip(_default, sep(16)),
      diaryClip(_default, sep(16), ordinal: 2),
      diaryClip(_default, sep(16), ordinal: 3),
    ]);

    subject.selectDay(sep(9));
    expect(subject.state.selectedClips, isEmpty);
  });

  test('selecting a day takes any past day, shows the month of a day of '
      'another month, and ignores a day to come or any day before the diary '
      'is read', () async {
    final DiaryCubit subject = cubit()..selectDay(sep(3));
    expect(subject.state.selected, sep(28));

    clips.publish(clipIndexOf(_default, <LocalDay>[sep(10), sep(16)]));
    await pumpEventQueue();
    for (final LocalDay day in <LocalDay>[sep(16), sep(12), sep(3)]) {
      subject.selectDay(day);
      expect(subject.state.selected, day);
    }
    subject.selectDay(sep(29));
    expect(subject.state.selected, sep(3));

    subject.selectDay(LocalDay(2026, 3, 4));
    expect(subject.state.month, const DiaryMonth(2026, 3));
    expect(subject.state.selected, LocalDay(2026, 3, 4));
  });

  group('following the diary', () {
    test('a clip saved elsewhere shows at once; the month and the day '
        'stay', () async {
      clips.publish(clipIndexOf(_default, <LocalDay>[sep(1), sep(28)]));
      final DiaryCubit subject = cubit()..selectDay(sep(1));

      clips.publish(clipIndexOf(_default, <LocalDay>[sep(1), sep(9), sep(28)]));
      await pumpEventQueue();

      expect(subject.state.dayOf(sep(9)).kind, DiaryDayKind.recorded);
      expect(subject.state.month, const DiaryMonth(2026, 9));
      expect(subject.state.selected, sep(1));
    });

    test('a diary that cannot be read says so instead of loading forever; '
        '"Try again" loads, then fails again or shows the diary', () async {
      final DiaryCubit subject = cubit();
      clips.fail(_default, const StorageException('unreadable'));
      await pumpEventQueue();
      expect(subject.state.status, DiaryStatus.failed);

      final List<DiaryStatus> seen = <DiaryStatus>[];
      subject.stream.listen((DiaryState state) => seen.add(state.status));
      clips.rescanError = const StorageException('still unreadable');
      await subject.readAgain();
      clips
        ..rescanError = null
        ..rescanResult = clipIndexOf(_default, <LocalDay>[sep(3), sep(20)]);
      await subject.readAgain();
      await pumpEventQueue();

      expect(seen, <DiaryStatus>[
        DiaryStatus.loading,
        DiaryStatus.failed,
        DiaryStatus.loading,
        DiaryStatus.ready,
      ]);
      expect(subject.state.selected, sep(20));
      expect(clips.rescanned, <ProfileKey>[_default, _default]);
    });

    test('another profile made active shows its diary on this month, today '
        'selected (diary.md §0.5), and keeps the paused player and the sound '
        'the user chose', () async {
      const ProfileKey trip = ProfileKey('Trip');
      profiles.addProfile(
        testProfile(key: trip, orientation: VideoOrientation.portrait),
      );
      clips
        ..publish(clipIndexOf(_default, d1Days))
        ..publish(clipIndexOf(trip, <LocalDay>[sep(2), sep(28)]));
      final DiaryCubit subject = cubit()..showPreviousMonth();
      await subject.playbackChosen(playing: false);
      await subject.toggleSound();

      await profiles.activate(trip);
      await pumpEventQueue();

      expect(subject.state.profile.key, trip);
      expect(subject.state.profile.orientation, VideoOrientation.portrait);
      expect(subject.state.month, const DiaryMonth(2026, 9));
      expect(subject.state.selected, sep(28));
      expect(subject.state.monthCount, (recorded: 2, total: 27));
      expect(subject.state.autoPlay, isFalse);
      expect(subject.state.muted, isFalse);

      clips.publish(clipIndexOf(_default, <LocalDay>[sep(5)]));
      await pumpEventQueue();
      expect(subject.state.dayOf(sep(5)).kind, DiaryDayKind.missed);
    });

    test('today moves on at midnight', () async {
      clips.publish(clipIndexOf(_default, d1Days));
      final MidnightTicker midnight = MidnightTicker(clock: clock);
      final DiaryCubit subject = DiaryCubit(
        profiles: profiles,
        clips: clips,
        settings: settings,
        midnight: midnight,
        captions: ClipCaptions(clips: clips, metadata: metadata),
        filtering: ClipFiltering(metadata: metadata),
        store: store,
        share: share,
        opener: opener,
        paths: paths,
        logger: memoryLogger(MemoryLogSink()),
      );
      made.add(subject);

      clock.setNow(DateTime(2026, 9, 29, 0, 0, 1));
      midnight.check();
      await pumpEventQueue();

      expect(subject.state.today, sep(29));
      expect(subject.state.dayOf(sep(29)).isToday, isTrue);
      expect(subject.state.dayOf(sep(29)).kind, DiaryDayKind.missed);
    });
  });

  group('alternative colours (Q-D1)', () {
    test('are off by default, as in v1.7, and follow the preference, also '
        'when it changes while the tab is open', () async {
      expect(cubit().state.alternativeColors, isFalse);

      await settings.useAlternativeCalendarColors.set(true);
      final DiaryCubit subject = cubit();
      expect(subject.state.alternativeColors, isTrue);

      await settings.useAlternativeCalendarColors.set(false);
      await pumpEventQueue();
      expect(subject.state.alternativeColors, isFalse);
    });
  });

  group('Make movie', () {
    test('needs 2 clips in the month; two of one day are enough (decision '
        'D1)', () {
      clips.publish(diaryIndex(_default, <LocalDay, int>{sep(4): 1}));
      final DiaryCubit subject = cubit();
      expect(subject.state.canMakeMovieOf(subject.state.month), isFalse);

      clips.publish(
        diaryIndex(_default, <LocalDay, int>{
          LocalDay(2026, 7, 30): 1,
          LocalDay(2026, 8, 2): 2,
          sep(4): 2,
        }),
      );
      final DiaryState two = cubit().state;
      expect(two.canMakeMovieOf(two.month), isTrue);
      expect(two.canMakeMovieOf(const DiaryMonth(2026, 8)), isTrue);
      expect(two.canMakeMovieOf(const DiaryMonth(2026, 7)), isFalse);
    });
  });

  test('the view switches to Memories and back keeping the month; J1 asks '
      "for this month's calendar however it was left", () async {
    clips.publish(clipIndexOf(_default, d1Days));
    final DiaryCubit subject = cubit()..showPreviousMonth();
    expect(subject.state.view, DiaryView.calendar);

    subject.showView(DiaryView.memories);
    expect(subject.state.view, DiaryView.memories);
    expect(subject.state.month, const DiaryMonth(2026, 8));

    // The Journey's "This month" and "Days recorded" tiles.
    opener.showThisMonthsCalendar();
    await pumpEventQueue();

    expect(subject.state.view, DiaryView.calendar);
    expect(subject.state.month, const DiaryMonth(2026, 9));
    expect(subject.state.selected, sep(28));
  });

  group('the clip the player shows (decision D1: a day\'s clips in order)', () {
    test("is the selected day's first clip and pages through the day's "
        'clips, staying within them; a new day starts at its first, a missed '
        'day has none', () {
      clips.publish(
        diaryIndex(_default, <LocalDay, int>{sep(16): 3, sep(28): 2}),
      );
      final DiaryCubit subject = cubit()..selectDay(sep(16));
      expect(subject.state.shownClip, diaryClip(_default, sep(16)));
      expect(subject.state.shownPosition, 0);

      subject.showClipAt(1);
      expect(subject.state.shownClip, diaryClip(_default, sep(16), ordinal: 2));

      subject.showClipAt(2);
      expect(subject.state.shownClip, diaryClip(_default, sep(16), ordinal: 3));
      expect(subject.state.shownPosition, 2);
      subject.showClipAt(7);
      expect(subject.state.shownPosition, 2);
      expect(subject.state.shownClip, diaryClip(_default, sep(16), ordinal: 3));

      subject.selectDay(sep(28));
      expect(subject.state.shownClip, diaryClip(_default, sep(28)));

      subject.selectDay(sep(9));
      expect(subject.state.shownClip, isNull);
    });

    test(
      'falls back to the day\'s first clip when the one shown goes',
      () async {
        clips.publish(diaryIndex(_default, <LocalDay, int>{sep(16): 2}));
        final DiaryCubit subject = cubit()..selectDay(sep(16));
        subject.showClipAt(1);

        clips.publish(diaryIndex(_default, <LocalDay, int>{sep(16): 1}));
        await pumpEventQueue();

        expect(subject.state.shownClip, diaryClip(_default, sep(16)));
        expect(subject.state.shownPosition, 0);
      },
    );

    test('keeps the clips played before and after it warm: the day\'s own '
        'first, then the closest recorded days', () {
      clips.publish(
        diaryIndex(_default, <LocalDay, int>{
          sep(3): 1,
          sep(16): 2,
          sep(20): 1,
        }),
      );
      final DiaryCubit subject = cubit()..selectDay(sep(16));
      expect(subject.state.neighboursOf(subject.state.shownClip!), (
        previous: diaryClip(_default, sep(3)),
        next: diaryClip(_default, sep(16), ordinal: 2),
      ));

      subject.showClipAt(1);
      expect(subject.state.neighboursOf(subject.state.shownClip!), (
        previous: diaryClip(_default, sep(16)),
        next: diaryClip(_default, sep(20)),
      ));

      subject.selectDay(sep(20));
      expect(subject.state.neighboursOf(subject.state.shownClip!), (
        previous: diaryClip(_default, sep(16), ordinal: 2),
        next: null,
      ));
    });
  });

  group('sound and autoplay (Q-D8)', () {
    test('the player starts muted, so it never stops the user\'s music, '
        'even after sound was on in v1.7; the toggle unmutes and remembers '
        'the choice, and a choice made in the viewer is followed', () async {
      settings = SettingsRepository(
        prefs: await openLegacyPrefs(<String, Object>{
          ...legacyPrefs(),
          'calendarAutoSound': true,
        }),
      );
      expect(cubit().state.muted, isTrue);

      final DiaryCubit subject = cubit();
      await subject.toggleSound();
      expect(subject.state.muted, isFalse);
      expect(settings.calendarAutoSound.value, isTrue);
      await subject.toggleSound();
      expect(subject.state.muted, isTrue);
      expect(settings.calendarAutoSound.value, isFalse);

      // The viewer's toggle.
      await settings.calendarAutoSound.set(true);
      await pumpEventQueue();
      expect(subject.state.muted, isFalse);
    });

    test('plays on its own by default (v1.7), and remembers the user\'s '
        'last play or pause', () async {
      final DiaryCubit subject = cubit();
      expect(subject.state.autoPlay, isTrue);

      await subject.playbackChosen(playing: false);
      expect(subject.state.autoPlay, isFalse);
      expect(settings.calendarAutoPlay.value, isFalse);
      expect(cubit().state.autoPlay, isFalse);

      await subject.playbackChosen(playing: true);
      expect(subject.state.autoPlay, isTrue);
      expect(settings.calendarAutoPlay.value, isTrue);
    });
  });

  test('a day opened from elsewhere (forcedDate, one-shot: Q-D13, CL-37) '
      'shows that day in its month, on the clip given, once; a day to come '
      'is ignored', () {
    clips.publish(
      diaryIndex(_default, <LocalDay, int>{
        LocalDay(2026, 7, 4): 2,
        sep(16): 1,
      }),
    );
    final DiaryCubit subject = cubit();

    subject.showDay(sep(30));
    expect(subject.state.selected, sep(16));

    subject.showDay(
      LocalDay(2026, 7, 4),
      clip: diaryClip(_default, LocalDay(2026, 7, 4), ordinal: 2),
    );
    expect(subject.state.month, const DiaryMonth(2026, 7));
    expect(subject.state.selected, LocalDay(2026, 7, 4));
    expect(
      subject.state.shownClip,
      diaryClip(_default, LocalDay(2026, 7, 4), ordinal: 2),
    );

    subject.showNextMonth();
    expect(subject.state.month, const DiaryMonth(2026, 8));
    subject.showThisMonth();
    expect(subject.state.selected, sep(16));
  });

  test('adding a clip to a day (D2) is in progress while the add flow runs; '
      'the clip saved shows its day, and giving up ends it too', () async {
    clips.publish(clipIndexOf(_default, <LocalDay>[sep(1)]));
    final DiaryCubit subject = cubit()..selectDay(sep(9));

    subject
      ..addStarted()
      ..addFinished();
    expect(subject.state.adding, isFalse);
    expect(subject.state.selected, sep(9));

    subject.addStarted();
    expect(subject.state.adding, isTrue);

    clips.publish(clipIndexOf(_default, <LocalDay>[sep(1), sep(9)]));
    await pumpEventQueue();
    subject.addFinished(saved: diaryClip(_default, sep(9)));

    expect(subject.state.adding, isFalse);
    expect(subject.state.selected, sep(9));
    expect(subject.state.dayOf(sep(9)).kind, DiaryDayKind.recorded);
  });

  group('deleting a clip (D5, Q-D9: permanent, no Undo)', () {
    test('runs, then says it is done; the day turns missed and the trash '
        'forgets the backup', () async {
      clips.publish(clipIndexOf(_default, <LocalDay>[sep(1), sep(16)]));
      final DiaryCubit subject = cubit()..selectDay(sep(16));
      store.hold = true;

      final Future<void> deleting = subject.deleteClip(
        diaryClip(_default, sep(16)),
      );
      expect(subject.state.deletion, ClipDeletion.deleting);
      store.release();
      await deleting;
      await pumpEventQueue();

      expect(subject.state.deletion, ClipDeletion.deleted);
      expect(subject.state.deletedClip, diaryClip(_default, sep(16)));
      expect(subject.state.selected, sep(16));
      expect(subject.state.dayOf(sep(16)).kind, DiaryDayKind.missed);
      // The delete stays revertible: its snackbar offers Undo, and makes
      // it final when it leaves.
      expect(store.dismissed, isEmpty);
      expect(store.deletionOf(diaryClip(_default, sep(16))), isNotNull);
    });

    test('a refusal says so every time, and the clip stays', () async {
      clips.publish(clipIndexOf(_default, <LocalDay>[sep(16)]));
      final DiaryCubit subject = cubit()..selectDay(sep(16));
      store.refuse = true;
      final List<ClipDeletion> seen = <ClipDeletion>[];
      subject.stream.listen((DiaryState state) => seen.add(state.deletion));

      await subject.deleteClip(diaryClip(_default, sep(16)));
      await subject.deleteClip(diaryClip(_default, sep(16)));
      await pumpEventQueue();

      expect(seen, <ClipDeletion>[
        ClipDeletion.deleting,
        ClipDeletion.failed,
        ClipDeletion.deleting,
        ClipDeletion.failed,
      ]);
      expect(subject.state.dayOf(sep(16)).kind, DiaryDayKind.recorded);
    });
  });

  test('sharing a clip (Memories\' long press, Q-D10) hands its file as it '
      'is stored to the share sheet', () async {
    clips.publish(clipIndexOf(_default, <LocalDay>[sep(16)]));

    await cubit().shareClip(
      diaryClip(_default, sep(16)),
      origin: const Rect.fromLTWH(16, 100, 358, 196),
    );

    expect(share.sharedFiles.single, <String>[
      paths.absoluteFromVideos(diaryClip(_default, sep(16)).relPath),
    ]);
    expect(share.lastOrigin, const Rect.fromLTWH(16, 100, 358, 196));
  });
}

/// The fake library, whose [rescan] the test scripts: the diary it reads
/// again ([rescanResult]), or the failure it meets ([rescanError]).
class _RescannableClips extends FakeClipRepository {
  ClipIndex? rescanResult;
  Object? rescanError;

  @override
  Future<ClipIndex> rescan(ProfileKey profile) async {
    final ClipIndex index = await super.rescan(profile);
    final Object? error = rescanError;
    if (error != null) throw error;
    return rescanResult ?? index;
  }
}
