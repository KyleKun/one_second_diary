import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/app/launch/gated_media_engine.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';
import 'package:one_second_diary/app/launch/post_frame_launch.dart';
import 'package:one_second_diary/app/wiring/legacy_counter_wiring.dart';
import 'package:one_second_diary/app/wiring/library_wiring.dart';
import 'package:one_second_diary/app/wiring/reminder_plan_wiring.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/di/launch_core.dart';
import 'package:one_second_diary/core/location/location_service.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/migrations/legacy_folder_migration.dart';
import 'package:one_second_diary/core/migrations/orphan_sweep.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/legacy_prefs_mirror.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/clip_subtitles.dart';
import 'package:one_second_diary/features/clips/data/import_flow.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/presentation/recovered/recovered_clip_cubit.dart';
import 'package:one_second_diary/features/movies/data/movie_builder.dart';
import 'package:one_second_diary/features/movies/data/movie_index.dart';
import 'package:one_second_diary/features/movies/data/movie_repository.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/onboarding/data/onboarding_store.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/reminders/data/reminder_scheduler.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_cubit.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../support/support.dart';

/// A gallery that never answers, as the plugin does for a native failure
/// other than consent.
class _SilentMediaStoreGateway extends Fake implements MediaStoreGateway {
  @override
  Future<bool> delete({required String absolutePath, required String album}) =>
      Completer<bool>().future;
}

void main() {
  // The coordinator follows the app lifecycle through the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeClock clock;
  late MemoryLogSink sink;
  late LaunchCore core;
  late FakeGateways gateways;

  setUp(() async {
    await sl.reset();
    clock = FakeClock(DateTime(2024, 1, 5, 10));
    sink = MemoryLogSink();
    final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
    final AppPaths paths = AppPaths.forTest(await createTempRoot());
    core = LaunchCore(
      clock: clock,
      prefs: prefs,
      paths: paths,
      logger: memoryLogger(sink, clock: clock),
      logSession: null,
      settings: SettingsRepository(prefs: prefs),
      isAndroid: false,
      isIOS: false,
      deviceLanguageCode: () => 'de',
    );
    gateways = FakeGateways(clock: clock, paths: paths);
  });

  tearDown(() async {
    await sl.reset();
    await gateways.close();
  });

  // get_it fails only when a type is first read, at run time: this reads the
  // whole graph once.
  test('builds every service, cubit and the router over the fake gateways, '
      'sharing what bootstrap built before the first frame', () {
    registerDependencies(core: core, overrides: gateways.register);

    expect(<Object>[
      sl<ClipStore>(),
      sl<ClipRepository>(),
      sl<ClipMetadataBackfill>(),
      sl<ThumbnailRepository>(),
      sl<PlayerPool>(param1: true),
      sl<MovieIndex>(),
      sl<MovieRepository>(),
      sl<MovieBuilder>(),
      sl<ProfilesRepository>(),
      sl<OnboardingStore>(),
      sl<LegacyPrefsMirror>(),
      sl<LegacyFolderMigration>(),
      sl<OrphanSweep>(),
      sl<MediaPublisher>(instanceName: DiNames.launchChain),
      sl<ReminderScheduler>(),
      sl<MidnightTicker>(),
      sl<LocationService>(),
      sl<PermissionRequester>(),
      sl<BugReportService>(),
      sl<ImportFlow>(),
      sl<ClipSubtitles>(),
      sl<ReminderPlanWiring>(),
      sl<LibraryWiring>(),
      sl<LegacyCounterWiring>(),
      sl<PostFrameLaunch>(),
      sl<LaunchCubit>(),
      sl<ThemeCubit>(),
      sl<ProfilesCubit>(),
      sl<CreateMovieCubit>(param1: const CreateMovieArgs()),
      sl<GoRouter>(),
    ], everyElement(isNotNull));
    // No media job before the launch's sweep.
    expect(sl<MediaEngine>(), isA<GatedMediaEngine>());
    // The device language, while none is picked.
    expect(sl<LocaleCubit>().state.language, AppLanguage.de);
    // App-scoped: the app root offers, the pages take the same one.
    expect(sl<RecoveredClipCubit>(), same(sl<RecoveredClipCubit>()));
    expect(sl<ThemeCubit>(), same(sl<ThemeCubit>()));
    expect(
      sl<CreateMovieCubit>(param1: const CreateMovieArgs()),
      isNot(same(sl<CreateMovieCubit>(param1: const CreateMovieArgs()))),
    );
    expect(sl<PrefsStore>(), same(core.prefs));
    expect(sl<AppPaths>(), same(core.paths));
    expect(sl<AppLogger>(), same(core.logger));
    expect(sl<SettingsRepository>(), same(core.settings));
    expect(sl<Clock>(), same(core.clock));
  });

  // Only the callers that must finish give up on a call that never answers;
  // the clip-saving publisher waits, since it deletes the render on false
  // and a late consent would lose the clip.
  test('gives up on an unanswered gallery call only where the caller must '
      'finish', () {
    registerDependencies(
      core: core,
      overrides: (GetIt sl) {
        gateways.register(sl);
        sl.registerSingleton<MediaStoreGateway>(_SilentMediaStoreGateway());
      },
    );

    fakeAsync((FakeAsync async) {
      bool? saving;
      bool? launchChain;
      bool? profileDeletion;
      unawaited(
        sl<MediaPublisher>()
            .deleteWithoutUndo('2024-01-05.mp4')
            .then((bool done) => saving = done),
      );
      unawaited(
        sl<MediaPublisher>(instanceName: DiNames.launchChain)
            .deleteWithoutUndo('2024-01-05.mp4')
            .then((bool done) => launchChain = done),
      );
      unawaited(
        sl<MediaStoreGateway>(instanceName: DiNames.profileDeletion)
            .delete(
              absolutePath: '${core.paths.videos}2024-01-05.mp4',
              album: 'OneSecondDiary',
            )
            .then((bool done) => profileDeletion = done),
      );

      async.elapse(launchChainTimeLimit);
      expect(launchChain, isFalse);
      expect(profileDeletion, isNull, reason: 'time to answer a prompt');

      async.elapse(profileDeletionTimeLimit);
      expect(profileDeletion, isFalse);

      async.elapse(const Duration(hours: 1));
      expect(saving, isNull);
    });
  });
}
