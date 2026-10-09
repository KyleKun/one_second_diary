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
import 'package:one_second_diary/features/clips/data/clip_audio.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_tags.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/data/clip_captions.dart';
import 'package:one_second_diary/features/diary/data/clip_filtering.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/pages/viewer_page.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/theme/osd_forced_dark.dart';
import 'package:one_second_diary/theme/osd_theme.dart';

import '../../../shared/fakes/fake_clip_audio.dart';
import '../../../shared/fakes/fake_clip_tags.dart';
import '../../../shared/fakes/fake_profiles_repository.dart';
import '../../../shared/harness/clip_media_harness.dart';
import '../../../shared/harness/settle.dart';
import '../../../support/support.dart';
import 'diary_fixtures.dart';
import 'fake_clip_store.dart';

/// The viewer on its own, in the app's themes and real translations,
/// over fakes: the index ([publish]), the thumbnails and players
/// ([media]), a real [ViewerCubit]. A home page opens it with
/// `ViewerArgs(…).push<ClipRef>` and keeps what it closes with ([result]).
final class ViewerPageHarness {
  ViewerPageHarness()
    : profiles = FakeProfilesRepository(),
      media = ClipMediaHarness(),
      share = FakeShareGateway();

  static const String _home = '/home';

  /// The page under the viewer.
  static const Key homeKey = Key('viewerPageHarness.home');

  final FakeProfilesRepository profiles;
  final ClipMediaHarness media;
  final FakeShareGateway share;

  late final FakeClipStore store = FakeClipStore(media.clips);
  late final ClipMetadataCache metadata = ClipMetadataCache(
    paths: media.paths,
    logger: memoryLogger(MemoryLogSink()),
  );
  late final SettingsRepository settings;

  /// Writes tags into [media]'s index (the tags sheet's Save).
  late final FakeClipTags clipTags = FakeClipTags(media.clips);

  /// Mutes clips in memory (the Mute tile and row).
  final FakeClipAudio audio = FakeClipAudio();

  /// The chips' colours, over the test's preferences.
  late final TagColors tagColors;
  late final GoRouter router;

  /// The viewer's cubit, once it is open.
  late ViewerCubit cubit;

  /// What the viewer closed with; [closed] once it did.
  ClipRef? result;
  bool closed = false;

  /// Makes [clipsPerDay] the Default profile's diary.
  void publish(Map<LocalDay, int> clipsPerDay) =>
      media.clips.publish(diaryIndex(ProfileKey.defaultProfile, clipsPerDay));

  /// Opens the viewer on [clip] on a 390 × 844 phone, with the viewer's
  /// own pool (sound per `calendarAutoSound`), and settles.
  Future<void> open(WidgetTester tester, ClipRef clip) async {
    EasyLocalization.logger.enableLevels = [];
    await tester.runAsync(initializeDateFormatting);
    final PrefsStore prefs = (await tester.runAsync(
      () => openLegacyPrefs(legacyPrefs()),
    ))!;
    settings = SettingsRepository(prefs: prefs);
    tagColors = TagColors(prefs: prefs, logger: memoryLogger(MemoryLogSink()));
    await media.pool.dispose();
    media.pool = PlayerPool(
      factory: media.players,
      logger: memoryLogger(MemoryLogSink()),
      muted: !settings.calendarAutoSound.value,
    );
    router = GoRouter(
      initialLocation: _home,
      routes: <RouteBase>[
        GoRoute(
          path: _home,
          builder: (BuildContext context, _) =>
              const SizedBox.expand(key: homeKey),
        ),
        GoRoute(
          path: AppRoute.viewer.path,
          builder: (BuildContext context, GoRouterState state) => OsdForcedDark(
            child: BlocProvider<ViewerCubit>(
              create: (_) => cubit = ViewerCubit(
                args: state.extra! as ViewerArgs,
                profiles: profiles,
                clips: media.clips,
                captions: ClipCaptions(clips: media.clips, metadata: metadata),
                filtering: ClipFiltering(metadata: metadata),
                store: store,
                share: share,
                paths: media.paths,
                settings: settings,
                logger: memoryLogger(MemoryLogSink()),
              ),
              child: const ViewerPage(key: ValueKey<AppRoute>(AppRoute.viewer)),
            ),
          ),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await tagColors.dispose();
      await profiles.close();
      await media.dispose();
      rootBundle.clear();
    });
    tester.view
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiRepositoryProvider(
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
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    final BuildContext home = tester.element(find.byKey(homeKey));
    ViewerArgs(clip: clip).push<ClipRef>(home).then((ClipRef? clip) {
      result = clip;
      closed = true;
    }).ignore();
    await settle(tester);
  }
}
