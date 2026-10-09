import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/data/filmstrip_frames.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/pages/edit_clip_page.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../shared/fakes/fake_bug_reports.dart';
import '../../../shared/fakes/fake_clip_repository.dart';
import '../../../shared/fakes/fake_profiles_repository.dart';
import '../../../shared/harness/settle.dart';
import '../../../shared/robots/shell_robot.dart';
import '../../../shared/widgets/support/osd_widget_harness.dart';
import '../../../support/support.dart';
import 'fake_clip_saver.dart';
import 'fake_filmstrip_frames.dart';
import 'fake_location_service.dart';
import 'fake_recent_places.dart';

/// A camera recording, the clip editor's usual source.
const VideoSource editorRecording = VideoSource(
  path: '/tmp/REC.mp4',
  ownership: ClipOwnership.cameraTemp,
);

/// A photo picked from the gallery.
const PhotoSource editorPhoto = PhotoSource(
  path: '/tmp/IMG.jpg',
  ownership: ClipOwnership.pickerCopy,
);

/// The day the editor files the clip under.
final LocalDay editorDay = LocalDay(2024, 1, 5);

/// A widget-test harness for the clip editor: a real [EditClipCubit], a
/// real [PlayerPool] over fake [players], a real [SavedPlaces] store over
/// the preferences, and fakes for what the editor reaches ([saver],
/// [locations], [recentPlaces], [reports]).
///
/// ```dart
/// final EditClipHarness editor = EditClipHarness();
/// addTearDown(editor.dispose);
/// await editor.open(editorRecording);
/// await editor.pump(tester, const LocationTab());
/// ```
final class EditClipHarness {
  EditClipHarness()
    : players = FakePlayerFactory(),
      frames = FakeFilmstripFrames(),
      locations = FakeLocationService(),
      recentPlaces = FakeRecentPlaces(),
      saver = FakeClipSaver(),
      reports = FakeBugReports(),
      permissions = FakePermissionGateway(),
      log = MemoryLogSink() {
    pool = PlayerPool(factory: players, logger: memoryLogger(log), muted: true);
  }

  final FakePlayerFactory players;
  final FakeFilmstripFrames frames;
  final FakeLocationService locations;

  /// The clips' places the place sheet offers as "Recent".
  final FakeRecentPlaces recentPlaces;

  /// The places saved, over the same preferences as [settings].
  late SavedPlaces savedPlaces;

  /// What Save and Discard reach.
  final FakeClipSaver saver;

  /// What "Report error" reaches.
  final FakeBugReports reports;

  /// What "Open settings" reaches (the location dialog).
  final FakePermissionGateway permissions;
  final MemoryLogSink log;
  late final PlayerPool pool;
  late SettingsRepository settings;

  late EditClipCubit cubit;

  /// Opens the editor on [source] for [mode].
  Future<void> open(
    ClipSource source, {
    ClipSaveMode mode = const AddClip(),
  }) async {
    final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
    settings = SettingsRepository(prefs: prefs);
    savedPlaces = SavedPlaces(prefs: prefs, logger: memoryLogger(log));
    cubit = EditClipCubit(
      args: EditClipArgs(
        source: source,
        day: editorDay,
        profile: ProfileKey.defaultProfile,
        mode: mode,
      ),
      settings: settings,
      clips: FakeClipRepository(),
      locations: locations,
      savedPlaces: savedPlaces,
      metadata: recentPlaces,
      saver: saver,
      logger: memoryLogger(log),
    );
  }

  /// The player the pool made for the source, the last one.
  FakePlayerHandle get player => players.created.last;

  /// Pumps [child] with the editor's cubit, pool and frames.
  Future<void> pump(WidgetTester tester, Widget child) => pumpOsd(
    tester,
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<PlayerPool>.value(value: pool),
        RepositoryProvider<FilmstripFrames>.value(value: frames),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ProfilesCubit>.value(value: _profiles()),
          BlocProvider<EditClipCubit>.value(value: cubit),
        ],
        child: child,
      ),
    ),
    alignment: Alignment.topCenter,
  );

  ProfilesCubit _profiles() {
    final ProfilesCubit profilesCubit = ProfilesCubit(
      profiles: FakeProfilesRepository(),
      clips: FakeClipRepository(),
      logger: memoryLogger(log),
    );
    addTearDown(profilesCubit.close);
    return profilesCubit;
  }

  /// Pushes the editor's page above an empty screen, as the app opens it
  /// for a result: what it pops with.
  Future<RouteResult<SavedClip>> pushPage(WidgetTester tester) async {
    await pumpOsd(tester, const SizedBox.expand(), scaffold: false);
    final RouteResult<SavedClip> result = RouteResult<SavedClip>(
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push<SavedClip>(
            MaterialPageRoute<SavedClip>(builder: (_) => _page()),
          ),
    );
    await settle(tester);
    return result;
  }

  Widget _page() => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<PlayerPool>.value(value: pool),
      RepositoryProvider<FilmstripFrames>.value(value: frames),
      RepositoryProvider<BugReportService>.value(value: reports),
      RepositoryProvider<PermissionRequester>(
        create: (_) => PermissionRequester(
          permissions: permissions,
          deviceInfo: FakeDeviceInfoGateway(),
          logger: memoryLogger(log),
        ),
      ),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<ProfilesCubit>.value(value: _profiles()),
        BlocProvider<EditClipCubit>.value(value: cubit),
      ],
      child: const EditClipPage(),
    ),
  );

  /// Lets the pool open the source's player (its `initialize` completes).
  Future<void> ready(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  Future<void> dispose() async {
    await cubit.close();
    await savedPlaces.dispose();
    await pool.dispose();
  }
}
