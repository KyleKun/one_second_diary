import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/osd_localization_root.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/data/clip_audio.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/presentation/recovered/recovered_clip_cubit.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_cubit.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_character_cubit.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_cubit.dart';
import 'package:one_second_diary/features/today/presentation/pages/today_page.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/theme/osd_theme.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

import '../../../shared/fakes/fake_clip_audio.dart';
import '../../../shared/fakes/fake_clip_caches.dart';
import '../../../shared/fakes/fake_clip_repository.dart';
import '../../../shared/fakes/fake_profiles_repository.dart';
import '../../../shared/harness/settle.dart';
import '../../../support/support.dart';
import 'today_diaries.dart';

export 'today_diaries.dart';

/// The Today page over fakes, with the app's theme and translations, as the
/// Today route builds it: its cubits over a [FakeClipRepository] the test
/// publishes to ([clips]), a [FakeProfilesRepository] and a [FakeClock]
/// (fake time drives the midnight ticker).
final class TodayPageHarness {
  TodayPageHarness._();

  late final FakeClock clock;
  final FakeClipRepository clips = FakeClipRepository();
  late final FakeProfilesRepository profilesRepository;
  late final ProfilesCubit profiles;
  late final SettingsRepository settings;
  late final UserNameCubit userName;
  late final MidnightTicker midnight;
  late final TodayCubit today;
  final FakeThumbnailRepository thumbnails = FakeThumbnailRepository();

  /// Mutes clips in memory (the Edit sheet's Mute).
  final FakeClipAudio audio = FakeClipAudio();
  final AppPaths paths = AppPaths.forTest(Directory('/osd'));
  final MemoryLogSink log = MemoryLogSink();

  /// The players Today's pool makes (inline play).
  final FakePlayerFactory players = FakePlayerFactory();

  /// Today's pool, as the Today route provides it (with sound).
  late final PlayerPool pool;

  /// Pumps Today on Monday, 28 September 2026, 18:12, with Default
  /// (landscape, active) and Travel (portrait), and the [diaries] already
  /// read (by default every profile's, empty; `[]` for a launch still
  /// reading them).
  static Future<TodayPageHarness> pump(
    WidgetTester tester, {
    List<ClipIndex>? diaries,
  }) async {
    final TodayPageHarness harness = TodayPageHarness._();
    final List<Profile> all = todayProfiles();
    final List<ClipIndex> read =
        diaries ??
        <ClipIndex>[
          for (final Profile profile in all)
            todayDiary(profile.key, const <LocalDay, int>{}),
        ];
    await harness._build(
      now: DateTime(2026, 9, 28, 18, 12),
      profiles: all,
      diaries: read,
    );
    addTearDown(harness._dispose);
    tester.view
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness._app());
    await settle(tester);
    return harness;
  }

  Future<void> _build({
    required DateTime now,
    required List<Profile> profiles,
    required List<ClipIndex> diaries,
  }) async {
    clock = FakeClock(now);
    diaries.forEach(clips.publish);
    profilesRepository = FakeProfilesRepository(profiles: profiles);
    settings = SettingsRepository(prefs: await openLegacyPrefs(legacyPrefs()));
    midnight = MidnightTicker(clock: clock);
    pool = PlayerPool(
      factory: players,
      logger: memoryLogger(log),
      muted: false,
    );
    this.profiles = ProfilesCubit(
      profiles: profilesRepository,
      clips: clips,
      logger: memoryLogger(log),
    );
    userName = UserNameCubit(settings: settings, logger: memoryLogger(log));
    today = TodayCubit(
      clips: clips,
      profiles: profilesRepository,
      midnight: midnight,
      clock: clock,
      settings: settings,
      logger: memoryLogger(log),
    );
  }

  Widget _app() => OsdLocalizationRoot(
    language: AppLanguage.en,
    // App-scoped, as `OsdApp` provides them: above the navigator.
    child: MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<AppPaths>.value(value: paths),
        RepositoryProvider<ClipRepository>.value(value: clips),
        RepositoryProvider<ClipAudio>.value(value: audio),
        RepositoryProvider<ThumbnailRepository>.value(value: thumbnails),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<Object?>>[
          BlocProvider<ProfilesCubit>.value(value: profiles),
          BlocProvider<UserNameCubit>.value(value: userName),
          BlocProvider<RecoveredClipCubit>(create: (_) => RecoveredClipCubit()),
        ],
        child: Builder(
          builder: (BuildContext context) => MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: OsdTheme.dark(
              typography: OsdTypography.forLocale(context.locale),
            ),
            // As the Today route provides them: the tab's pool and its
            // cubit, closed with the page.
            home: RepositoryProvider<PlayerPool>.value(
              value: pool,
              child: BlocProvider<TodayCubit>(
                create: (_) => today,
                child: BlocProvider<TodayCharacterCubit>(
                  create: (_) => TodayCharacterCubit(
                    today: today,
                    settings: settings,
                    clock: clock,
                    logger: memoryLogger(log),
                  ),
                  child: const Material(
                    child: OsdSnackbarHost(child: TodayPage()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// The page's providers closed the TodayCubit and the character's cubit
  /// with the tree (their timers stop at once). The rest lives in the test's fake-async zone, whose
  /// futures a tear-down cannot await: they are closed without waiting.
  void _dispose() {
    unawaited(userName.close());
    unawaited(profiles.close());
    unawaited(clips.close());
    unawaited(profilesRepository.close());
    unawaited(pool.dispose());
    rootBundle.clear();
  }
}
