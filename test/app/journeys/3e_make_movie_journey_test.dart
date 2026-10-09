// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_stats_bento.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/seeds.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

/// December 1–4, 2023, marked `isOsdV15`, at 1080p with sound: the movie
/// joins them as they are (no copy to make).
final List<LocalDay> _december = <LocalDay>[
  for (int day = 1; day <= 4; day++) LocalDay(2023, 12, day),
];

/// Today is January 5, 2024 (the harness's day): the movie's name.
const String _movie = 'OSD-Movie-1-2024-01-05.mp4';

void main() {
  /// The app over [_december]; ffmpeg writes what it is asked to and holds
  /// each session until the test lets it end. On Android ([isAndroid]) the
  /// phone says how much space is free: [freeBytes].
  Future<AppRobot> launch(
    WidgetTester tester, {
    bool isAndroid = false,
    int? freeBytes,
  }) => AppRobot.launch(
    tester,
    prefs: legacyPrefs(),
    isAndroid: isAndroid,
    seed: (AppPaths paths) async {
      for (final LocalDay day in _december) {
        await seedClip(paths, ProfileKey.defaultProfile, day);
      }
      await seedClipMeta(paths, <String, ClipMeta>{
        for (final LocalDay day in _december)
          '${day.fileStem}.mp4': const ClipMeta(
            durationMs: 1500,
            hasAudio: true,
            hasSubtitleStream: false,
            isOsdV15: true,
            width: 1920,
            height: 1080,
            codec: 'h264',
          ),
      });
    },
    configureGateways: (FakeGateways gateways) {
      gateways.freeSpace.free = freeBytes;
      gateways.ffmpeg
        ..holdExecutions = true
        ..onExecute = (List<String> arguments) async {
          // The concat's output comes before its final `-y`.
          final File output = File(arguments[arguments.length - 2]);
          await output.parent.create(recursive: true);
          await output.writeAsBytes(<int>[4, 2]);
        };
    },
  );

  /// What the app asks to free when nothing is: the movie's few test bytes,
  /// rounded up to a megabyte.
  String freeUpOneMegabyte() =>
      Strings.makingMovieNoSpace(size: Strings.movieSizeMegabytes(size: '1'));

  /// The confirmation on December 2023, from the Diary's Make movie, once the
  /// diary is read.
  Future<void> openDecember(AppRobot app) async {
    await app.shell.tapTab(AppRoute.diary);
    await app.shell.open(
      const CreateMovieArgs(source: MovieSource.month(year: 2023, month: 12)),
    );
    await app.harness.settleUntil(
      () => app.movies.canCreateMovie,
      reason: 'the diary was read',
    );
  }

  /// Taps Create movie and waits until ffmpeg joins the clips.
  Future<void> createMovie(AppRobot app) async {
    await app.movies.tapCreateMovie();
    await app.harness.settleUntil(
      () => app.movies.ffmpeg.heldSessions.isNotEmpty,
      reason: 'the clips are being joined',
    );
  }

  /// ffmpeg ends the join: the movie is saved and the job ends (its scratch
  /// folder deleted, the screen free to sleep).
  Future<void> finishJoin(AppRobot app) async {
    app.movies.ffmpeg.releaseHeld();
    await app.harness.settleUntil(
      () => app.movies.createdShown && !app.movies.wakelock.enabled,
      reason: "the movie is saved, then M7 takes M6's place",
    );
  }

  bool movieSaved(AppRobot app) =>
      File('${app.harness.paths.movies}$_movie').existsSync();

  testWidgets("the Diary's month made into a movie: M6 live while it is "
      'made, the screen awake, then M7, Share, and Done back to the Diary', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);
    await openDecember(app);

    await createMovie(app);

    app.shell.expectAt(AppRoute.makingMovie);
    expect(app.movies.makingTitle, Strings.makingMovieTitle);
    expect(app.movies.makingCount, Strings.makingMovieOfTotal(4, done: 0));
    expect(app.movies.wakelock.enabled, isTrue);

    await finishJoin(app);

    app.shell.expectAt(AppRoute.movieCreated);
    expect(movieSaved(app), isTrue);

    await app.movies.tapShare();
    expect(app.movies.share.sharedFiles, <List<String>>[
      <String>['${app.harness.paths.movies}$_movie'],
    ]);

    await app.movies.tapDone();
    app.shell.expectAt(AppRoute.diary);
    app.expectNoPluginChannel();
  });

  testWidgets("Watch plays the movie in the app's player; back returns to "
      'M7', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await openDecember(app);
    await createMovie(app);
    await finishJoin(app);

    await app.movies.tapWatch();

    app.shell.expectOpenedWith(const MoviePlayerArgs(file: _movie));
    await app.shell.pressBack();
    app.shell.expectAt(AppRoute.movieCreated);
    app.expectNoPluginChannel();
  });

  testWidgets('Cancel asks first; Stop ends the ffmpeg session, leaves no '
      'movie and returns to M5, where the movie can be made again', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);
    await openDecember(app);
    await createMovie(app);

    await app.movies.tapCancelMovie();
    await app.movies.tapKeepGoing();
    expect(app.movies.makingShown, isTrue);
    expect(app.movies.ffmpeg.cancelledSessions, isEmpty);

    await app.movies.tapCancelMovie();
    await app.movies.tapStop();
    await app.harness.settleUntil(
      () => !app.movies.makingShown && !app.movies.wakelock.enabled,
      reason: 'the session stopped and its files are gone',
    );

    expect(app.movies.ffmpeg.cancelledSessions, isNotEmpty);
    app.shell.expectAt(AppRoute.confirmMovie);
    expect(movieSaved(app), isFalse);
    expect(app.movies.wakelock.enabled, isFalse);
    expect(app.movies.canCreateMovie, isTrue);
    app.expectNoPluginChannel();
  });

  testWidgets('a failed join: why, Try again makes it after all', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);
    await openDecember(app);
    app.movies.ffmpeg.executeResults.add(FakeFfmpegGateway.failure());
    await createMovie(app);

    app.movies.ffmpeg.releaseHeld();
    await app.harness.settleUntil(
      () => app.movies.makingError != null && !app.movies.wakelock.enabled,
      reason: 'the join failed',
    );
    expect(app.movies.makingTitle, Strings.movieErrorTitle);
    expect(app.movies.makingError, Strings.makingMovieError);
    expect(movieSaved(app), isFalse);

    await app.movies.tapTryAgain();
    await app.harness.settleUntil(
      () => app.movies.ffmpeg.heldSessions.isNotEmpty,
      reason: 'the clips are joined again',
    );
    await finishJoin(app);
    expect(movieSaved(app), isTrue);
    app.expectNoPluginChannel();
  });

  testWidgets('from Journey: J1, M1, M5, M6, M7; Done returns to Journey, '
      'which counts the movie', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await app.shell.tapTab(AppRoute.journey);
    await app.harness.settleUntil(
      () => app.journey.hasNumber(JourneyTile.moviesMade),
      reason: 'the diary was read',
    );
    expect(app.journey.numberOf(JourneyTile.moviesMade), '0');

    await app.journey.tapCreateMovie();
    await app.movies.pickPreset(MoviePreset.allTime);
    await app.movies.tapContinue();
    await createMovie(app);
    await finishJoin(app);

    await app.movies.tapDone();

    app.shell.expectAt(AppRoute.journey);
    await app.harness.settleUntil(
      () => app.journey.numberOf(JourneyTile.moviesMade) == '1',
      reason: 'Journey counts the movies again',
    );
    app.expectNoPluginChannel();
  });

  testWidgets('the app left while the movie is made comes back to M6 as the '
      'movie is now, and on to M7 when it finished meanwhile', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);
    await openDecember(app);
    await createMovie(app);

    // The user switches to another app.
    <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await app.harness.settleUntil(
      () => app.movies.makingShown,
      reason: 'M6 stays while the app is away',
    );
    expect(app.movies.makingCount, Strings.makingMovieOfTotal(4, done: 0));

    app.movies.ffmpeg.releaseHeld();
    await app.harness.settleUntil(
      () => movieSaved(app) && !app.movies.wakelock.enabled,
      reason: 'the movie was made while the app was away',
    );
    // And comes back.
    <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await app.harness.settleUntil(
      () => app.movies.createdShown,
      reason: 'back in the app, M6 goes on to M7',
    );

    app.shell.expectAt(AppRoute.movieCreated);
    await app.movies.tapDone();
    app.shell.expectAt(AppRoute.diary);
    app.expectNoPluginChannel();
  });

  testWidgets('M6 gone while the movie is made (the app sent to Journey): '
      'Journey offers the movie in Create movie\'s place and brings M6 back '
      'as it is; the movie ends on M7, and Done returns to Journey', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);
    await app.shell.tapTab(AppRoute.journey);
    await app.harness.settleUntil(
      () => app.journey.hasNumber(JourneyTile.moviesMade),
      reason: 'the diary was read',
    );
    await app.journey.tapCreateMovie();
    await app.movies.pickPreset(MoviePreset.allTime);
    await app.movies.tapContinue();
    await createMovie(app);

    await app.shell.go(AppRoute.journey);

    expect(app.movies.makingShown, isFalse);
    expect(app.journey.offersMovieJob, isTrue);
    expect(app.journey.canCreateMovieShown, isFalse);
    expect(app.movies.wakelock.enabled, isTrue);

    await app.journey.tapMovieJob();

    app.shell.expectAt(AppRoute.makingMovie);
    expect(app.movies.makingTitle, Strings.makingMovieTitle);
    expect(app.movies.makingCount, Strings.makingMovieOfTotal(4, done: 0));

    await finishJoin(app);
    await app.movies.tapDone();

    app.shell.expectAt(AppRoute.journey);
    await app.harness.settleUntil(
      () => app.journey.numberOf(JourneyTile.moviesMade) == '1',
      reason: 'Journey counts the movie',
    );
    expect(app.journey.offersMovieJob, isFalse);
    expect(app.journey.canCreateMovie, isTrue);
    app.expectNoPluginChannel();
  });

  testWidgets('the phone fills up while the clips are joined (decision O12): '
      'M6 says so, offers Try again but no bug report, and Close returns to '
      'M5 with nothing left behind', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await openDecember(app);
    app.movies.ffmpeg.executeResults.add(
      FakeFfmpegGateway.failure(
        logs:
            '[mp4 @ 0x7b8c] Error writing trailer: No space left on device\n'
            'Conversion failed!',
      ),
    );
    await createMovie(app);

    app.movies.ffmpeg.releaseHeld();
    await app.harness.settleUntil(
      () => app.movies.makingError != null && !app.movies.wakelock.enabled,
      reason: 'the join failed on a full phone',
    );

    expect(app.movies.makingTitle, Strings.movieErrorTitle);
    // A phone that does not say how much is free (here: not Android).
    expect(app.movies.makingError, Strings.makingMovieNoSpaceUnknown);
    expect(app.movies.canReportError, isFalse);
    expect(app.movies.canTryAgain, isTrue);
    expect(movieSaved(app), isFalse);

    await app.movies.tapCloseMaking();

    app.shell.expectAt(AppRoute.confirmMovie);
    expect(app.movies.canCreateMovie, isTrue);
    expect(
      Directory(app.harness.paths.movies).existsSync()
          ? Directory(app.harness.paths.movies).listSync()
          : const <FileSystemEntity>[],
      isEmpty,
    );
    app.expectNoPluginChannel();
  });

  testWidgets('on Android, a full phone is caught at M5 before any work '
      '(decision O12): M5 says how much to free, and Create movie after '
      'freeing it makes the movie', (WidgetTester tester) async {
    final AppRobot app = await launch(tester, isAndroid: true, freeBytes: 0);
    await openDecember(app);

    await app.movies.tapCreateMovie();
    await app.harness.settleUntil(
      () => app.movies.confirmCallout == freeUpOneMegabyte(),
      reason: 'the phone said how much is free',
    );
    app.shell.expectAt(AppRoute.confirmMovie);
    expect(app.movies.ffmpeg.heldSessions, isEmpty);
    expect(app.movies.wakelock.enabled, isFalse);

    app.harness.gateways.freeSpace.free = 64000000000;
    await createMovie(app);
    await finishJoin(app);

    app.shell.expectAt(AppRoute.movieCreated);
    expect(movieSaved(app), isTrue);
    app.expectNoPluginChannel();
  });

  testWidgets('on Android, the phone filling up while the clips are joined '
      'is told with how much to free, and nothing is left behind', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(
      tester,
      isAndroid: true,
      freeBytes: 64000000000,
    );
    await openDecember(app);
    app.movies.ffmpeg.executeResults.add(
      FakeFfmpegGateway.failure(
        logs:
            '[mp4 @ 0x7b8c] Error writing trailer: No space left on device\n'
            'Conversion failed!',
      ),
    );
    await createMovie(app);

    // Another app filled the phone meanwhile.
    app.harness.gateways.freeSpace.free = 0;
    app.movies.ffmpeg.releaseHeld();
    await app.harness.settleUntil(
      () => app.movies.makingError != null && !app.movies.wakelock.enabled,
      reason: 'the join failed on a full phone',
    );

    expect(app.movies.makingError, freeUpOneMegabyte());
    expect(app.movies.canReportError, isFalse);
    expect(movieSaved(app), isFalse);
    app.expectNoPluginChannel();
  });
}
