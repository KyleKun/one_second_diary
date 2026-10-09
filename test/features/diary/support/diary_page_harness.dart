import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:one_second_diary/app/osd_localization_root.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/data/clip_audio.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_tags.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/diary/data/clip_captions.dart';
import 'package:one_second_diary/features/diary/data/clip_filtering.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/diary_opener.dart';
import 'package:one_second_diary/features/diary/presentation/pages/diary_page.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/theme/osd_theme.dart';

import '../../../shared/fakes/fake_clip_audio.dart';
import '../../../shared/fakes/fake_clip_tags.dart';
import '../../../shared/fakes/fake_profiles_repository.dart';
import '../../../shared/harness/clip_media_harness.dart';
import '../../../shared/harness/settle.dart';
import '../../../support/support.dart';
import 'diary_fixtures.dart';
import 'fake_clip_store.dart';

/// Monday, September 28, 2026, 22:50.
final DateTime diaryNow = DateTime(2026, 9, 28, 22, 50);

/// A day of September 2026.
LocalDay sep(int day) => LocalDay(2026, 9, day);

/// September: every day through the 28th but the 9th, 21st and 25th.
final Map<LocalDay, int> d1September = <LocalDay, int>{
  for (int day = 1; day <= 28; day++)
    if (day != 9 && day != 21 && day != 25) sep(day): 1,
};

/// The Diary page on its own, in the app's theme and real translations,
/// over fakes: the index ([publish]), the thumbnails ([media]), the
/// profiles and a real [DiaryCubit], inside a small router with a stand-in
/// viewer and a snackbar host as the shell has.
///
/// [pump] shows a blank page first, lets the translations load, then opens
/// the Diary in exactly one frame, so a test sees the page's first frame.
final class DiaryPageHarness {
  DiaryPageHarness({DateTime? now})
    : clock = FakeClock(now ?? diaryNow),
      profiles = FakeProfilesRepository(),
      media = ClipMediaHarness();

  /// What stands in for the viewer: its text is the clip it opened on.
  /// It is see-through, as the viewer is while dragged away (the Diary
  /// shows under it).
  static const Key viewerKey = Key('diaryPageHarness.viewer');

  /// What the viewer was opened with last.
  ViewerArgs? viewerArgs;
  static const String _blank = '/blank';

  final FakeClock clock;
  final FakeProfilesRepository profiles;

  /// The clip index, thumbnails, paths and player pool.
  final ClipMediaHarness media;

  late final DiaryCubit cubit;

  /// What the Diary shared.
  final FakeShareGateway share = FakeShareGateway();

  /// What the Journey's tiles ask of the Diary.
  final DiaryOpener opener = DiaryOpener();

  /// Deletes clips from [media]'s index.
  late final FakeClipStore store = FakeClipStore(media.clips);

  /// The clips' facts (subtitles, places), in memory.
  late final ClipMetadataCache metadata = ClipMetadataCache(
    paths: media.paths,
    logger: memoryLogger(MemoryLogSink()),
  );
  late final GoRouter router;
  late final SettingsRepository settings;

  /// Writes tags into [media]'s index (the tags sheet's Save).
  late final FakeClipTags clipTags = FakeClipTags(media.clips);

  /// Mutes clips in memory (the Mute tile and row).
  final FakeClipAudio audio = FakeClipAudio();

  /// The chips' colours, over the test's preferences.
  late final TagColors tagColors;

  /// Makes [clipsPerDay] the Default profile's diary.
  void publish(Map<LocalDay, int> clipsPerDay) =>
      media.clips.publish(diaryIndex(ProfileKey.defaultProfile, clipsPerDay));

  /// The current index.
  ClipIndex get index => media.clips.snapshotOf(ProfileKey.defaultProfile)!;

  /// Knows the [tier] thumbnail of every clip of the index.
  void cacheThumbnails(ThumbnailTier tier) {
    for (final ClipRef clip in index.newestFirst) {
      media.thumbnails.make(
        clip,
        stamp: index.stampOf(clip)!,
        tier: tier,
        path: thumbnailPathOf(clip, tier),
      );
    }
  }

  /// Where [cacheThumbnails] says [clip]'s [tier] thumbnail is.
  static String thumbnailPathOf(ClipRef clip, ThumbnailTier tier) =>
      '/thumbs/${clip.relPath}-${tier.name}.jpg';

  /// Opens the Diary on a 390 × 844 phone: the translations load behind a
  /// blank page, then the Diary shows in one frame.
  Future<void> pump(
    WidgetTester tester, {
    bool disableAnimations = false,
  }) async {
    EasyLocalization.logger.enableLevels = [];
    await tester.runAsync(initializeDateFormatting);
    final PrefsStore prefs = (await tester.runAsync(
      () => openLegacyPrefs(legacyPrefs()),
    ))!;
    settings = SettingsRepository(prefs: prefs);
    tagColors = TagColors(prefs: prefs, logger: memoryLogger(MemoryLogSink()));
    cubit = DiaryCubit(
      profiles: profiles,
      clips: media.clips,
      settings: settings,
      midnight: MidnightTicker(clock: clock),
      captions: ClipCaptions(clips: media.clips, metadata: metadata),
      filtering: ClipFiltering(metadata: metadata),
      store: store,
      share: share,
      opener: opener,
      paths: media.paths,
      logger: memoryLogger(MemoryLogSink()),
    );
    router = GoRouter(
      initialLocation: _blank,
      routes: <RouteBase>[
        GoRoute(path: _blank, builder: (_, _) => const SizedBox.shrink()),
        GoRoute(
          path: AppRoute.diary.path,
          builder: (_, _) => const OsdSnackbarHost(
            child: DiaryPage(key: ValueKey<AppRoute>(AppRoute.diary)),
          ),
        ),
        GoRoute(
          path: AppRoute.viewer.path,
          pageBuilder: (_, GoRouterState state) => CustomTransitionPage<void>(
            key: state.pageKey,
            opaque: false,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            transitionsBuilder: (_, _, _, Widget child) => child,
            child: Text(
              (viewerArgs = state.extra! as ViewerArgs).clip.relPath,
              key: viewerKey,
            ),
          ),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await tagColors.dispose();
      await profiles.close();
      await opener.dispose();
      await media.dispose();
      rootBundle.clear();
    });
    tester.view
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Unmounting the app closes the cubit, as the Diary's branch does, which
    // stops its midnight timer before the test's timer check.
    await tester.pumpWidget(
      BlocProvider<DiaryCubit>(
        create: (_) => cubit,
        lazy: false,
        child: MultiRepositoryProvider(
          providers: <RepositoryProvider<Object>>[
            RepositoryProvider<AppPaths>.value(value: media.paths),
            RepositoryProvider<ClipRepository>.value(value: media.clips),
            RepositoryProvider<ClipTags>.value(value: clipTags),
            RepositoryProvider<ClipAudio>.value(value: audio),
            RepositoryProvider<TagColors>.value(value: tagColors),
            RepositoryProvider<ThumbnailRepository>.value(
              value: media.thumbnails,
            ),
            RepositoryProvider<PlayerPool>.value(value: media.pool),
          ],
          child: OsdLocalizationRoot(
            language: AppLanguage.en,
            child: Builder(
              builder: (BuildContext context) => MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: OsdTheme.light(),
                darkTheme: OsdTheme.dark(),
                themeMode: ThemeMode.dark,
                themeAnimationDuration: Duration.zero,
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                routerConfig: router,
                builder: (BuildContext context, Widget? child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: disableAnimations),
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    router.go(AppRoute.diary.path);
    await tester.pump();
  }
}
