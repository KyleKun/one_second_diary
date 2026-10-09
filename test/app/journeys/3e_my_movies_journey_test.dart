// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_fade_through_page.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_stats_bento.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/seeds.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

/// Made for the Kids profile (shown as "Children"), before a reinstall lost
/// the movie index: its tags still say what it is.
const String _summer = 'OSD-Movie-3-2023-09-30.mp4';

/// Untagged, and moved by the user into a folder of their own.
const String _trip = 'Trips/OSD-Movie-2-2023-06-01.mp4';

/// A movie with no tags.
const String _first = 'OSD-Movie-1-2023-01-31.mp4';

// An untagged movie is titled by the day in its file name, shown as the
// language writes it (MovieLabels.baseTitle); the file keeps its name.

/// What ffprobe says of [_summer]: its title, its profile, its frame.
const String _summerTags =
    '{"format":{"duration":"37.5","tags":{"title":"Summer in Japan",'
    '"comment":"profile=Kids"}},'
    '"streams":[{"codec_type":"video","width":1920,"height":1080}]}';

/// What ffprobe says of an untagged movie.
const String _untagged =
    '{"format":{"duration":"12.0"},'
    '"streams":[{"codec_type":"video","width":1920,"height":1080}]}';

void main() {
  /// The app with Default and Kids ("Children"), and three movies in
  /// Movies/, newest first: [_summer], [_trip], [_first]. The index knows
  /// none of them; ffprobe reads their tags in that order.
  Future<AppRobot> launch(WidgetTester tester) => AppRobot.launch(
    tester,
    prefs: prefsWithProfiles(const <ProfileSeed>[
      ProfileSeed('Kids', orientation: 'portrait', displayName: 'Children'),
    ]),
    seed: (AppPaths paths) async {
      final DateTime made = DateTime(2023, 10);
      for (final (String file, int daysBefore) in <(String, int)>[
        (_summer, 0),
        (_trip, 1),
        (_first, 2),
      ]) {
        final File movie = await seedFile(paths, 'Movies/$file');
        await movie.setLastModified(made.subtract(Duration(days: daysBefore)));
      }
    },
    configureGateways: (FakeGateways gateways) => gateways.ffmpeg.probeResults
      ..add(FakeFfmpegGateway.success(output: _summerTags))
      ..add(FakeFfmpegGateway.success(output: _untagged))
      ..add(FakeFfmpegGateway.success(output: _untagged)),
  );

  /// My movies from Journey, once the tags are read.
  Future<void> openMyMovies(AppRobot app) async {
    await app.shell.tapTab(AppRoute.journey);
    await app.journey.tapMyMovies();
    await app.harness.settleUntil(
      () =>
          app.movies.hasMovie(_summer) &&
          app.movies.titleOf(_summer) == 'Summer in Japan' &&
          app.movies.profileOf(_summer) == 'Children',
      reason: "the movies' tags were read",
    );
  }

  bool onDisk(AppRobot app, String file) =>
      File('${app.harness.paths.movies}$file').existsSync();

  testWidgets("every profile's movies in one grid, newest first, the ones in "
      'a folder of Movies/ too; the index rebuilt from their tags; a tap '
      'plays one in the dark player, and close comes back', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);

    await openMyMovies(app);

    // The title is the movie's own; its profile is the label on the poster.
    expect(app.movies.movieTitles, <String>[
      'Summer in Japan',
      'Jun 1, 2023',
      'Jan 31, 2023',
    ]);
    expect(app.movies.hasMovie(_trip), isTrue);
    expect(app.movies.clipsOf(_first), isNull);

    await app.movies.tapMovie(_summer);
    await app.harness.settleUntil(
      () => app.movies.playerShown && app.movies.playerTitle != null,
      reason: 'the movie is still there, so it plays, and the player found it',
    );
    app.expectBrightness(Brightness.dark);
    expect(app.movies.playerTitle, 'Children · Summer in Japan');
    expect(app.movies.moviePlaying, isTrue);
    expect(
      app.harness.gateways.players.created.last.path,
      '${app.harness.paths.movies}$_summer',
    );

    await app.movies.tapPlayerScreen();
    expect(app.movies.moviePlaying, isFalse);

    await app.movies.closePlayer();
    expect(app.movies.myMoviesShown, isTrue);
    expect(app.movies.playerShown, isFalse);
    app.expectNoPluginChannel();
  });

  testWidgets('rename: a long press, Rename, a new title; it shows at once '
      'and is still there next time, the file unchanged', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);
    await openMyMovies(app);

    await app.movies.longPressMovie(_trip);
    expect(app.movies.selectionTitle, Strings.selectedCount(1));
    await app.movies.tapRename();
    expect(app.movies.nameInField, 'Jun 1, 2023');
    await app.movies.enterMovieName('  Road trip ');
    await app.movies.tapSaveName();
    await app.harness.settleUntil(
      () => app.movies.selectionTitle == null,
      reason: 'the title was saved, and selection ended',
    );
    expect(app.movies.titleOf(_trip), 'Road trip');

    await app.shell.pressBack();
    await app.journey.tapMyMovies();
    await app.harness.settleUntil(
      () => app.movies.hasMovie(_trip),
      reason: 'My movies was listed again',
    );
    expect(app.movies.titleOf(_trip), 'Road trip');
    expect(onDisk(app, _trip), isTrue);
    app.expectNoPluginChannel();
  });

  testWidgets('share and delete: two movies picked go to the share sheet '
      'together; Delete asks, then both leave the phone and the grid, and '
      'Journey counts one movie', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await openMyMovies(app);

    await app.movies.longPressMovie(_summer);
    await app.movies.tapMovie(_trip);
    expect(app.movies.selectionTitle, Strings.selectedCount(2));

    await app.movies.tapShareMovies();
    await app.harness.settleUntil(
      () => app.harness.gateways.share.sharedFiles.isNotEmpty,
      reason: 'both files are there, so both are shared',
    );
    expect(app.harness.gateways.share.sharedFiles.single, <String>[
      '${app.harness.paths.movies}$_summer',
      '${app.harness.paths.movies}$_trip',
    ]);
    expect(app.movies.selectionTitle, Strings.selectedCount(2));

    await app.movies.tapDeleteMovies();
    expect(app.movies.dialogTitle, Strings.deleteMoviesTitle(2));
    await app.movies.confirmDelete();
    await app.harness.settleUntil(
      () => !app.movies.hasMovie(_summer) && !app.movies.hasMovie(_trip),
      reason: 'the movies were deleted',
    );

    expect(app.movies.snackbarTitle, Strings.moviesDeleted(2));
    expect(app.movies.movieTitles, <String>['Jan 31, 2023']);
    expect(onDisk(app, _summer), isFalse);
    expect(onDisk(app, _trip), isFalse);
    expect(onDisk(app, _first), isTrue);

    await app.shell.pressBack();
    await app.harness.settleUntil(
      () => app.journey.numberOf(JourneyTile.moviesMade) == '1',
      reason: 'Journey counts the movies again',
    );
    app.expectNoPluginChannel();
  });

  testWidgets('filter by profile: Children keeps its one movie, live under '
      'the sheet; the movies made before profiles are a choice of their '
      'own; the filter stays after Done, and Clear shows all three', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);
    await openMyMovies(app);
    expect(app.movies.canFilterMovies, isTrue);
    expect(app.movies.moviesFiltered, isFalse);

    await app.movies.openMoviesFilter();
    expect(app.movies.moviesFilterShown, isTrue);
    await app.movies.pickMoviesProfile('Children');
    expect(app.movies.movieTitles, <String>['Summer in Japan']);

    await app.movies.pickMoviesProfile(Strings.movieFilterNoProfile);
    expect(app.movies.movieTitles, <String>[
      'Summer in Japan',
      'Jun 1, 2023',
      'Jan 31, 2023',
    ]);
    await app.movies.pickMoviesProfile('Children');
    await app.movies.tapMoviesFilterDone();
    expect(app.movies.moviesFilterShown, isFalse);
    expect(app.movies.moviesFiltered, isTrue);
    expect(app.movies.movieTitles, <String>['Jun 1, 2023', 'Jan 31, 2023']);
    expect(app.movies.moviesFilterMatches, Strings.movieFilterMatches(2));

    await app.movies.clearMoviesFilter();
    expect(app.movies.moviesFiltered, isFalse);
    expect(app.movies.movieTitles, hasLength(3));
    app.expectNoPluginChannel();
  });

  testWidgets('no movies yet: My movies says so, and Create movie opens M1 '
      'in its place', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    await app.shell.tapTab(AppRoute.journey);
    await app.journey.tapMyMovies();
    await app.harness.settleUntil(
      () => app.movies.saysNoMovies,
      reason: 'Movies/ was read',
    );
    await app.movies.tapCreateFirstMovie();

    app.shell.expectAt(AppRoute.createMovie);
    // Create movie takes My movies' place: the flow fades through.
    final Page<Object?> flow =
        ModalRoute.of(
              Navigator.of(app.shell.pageElement(AppRoute.createMovie)).context,
            )!.settings
            as Page<Object?>;
    expect(
      flow,
      isA<OsdFadeThroughPage<Object?>>().having(
        (OsdFadeThroughPage<Object?> page) => page.fadeThrough,
        'fadeThrough',
        isTrue,
      ),
    );
    await app.shell.pressBack();
    app.shell.expectAt(AppRoute.journey);
    app.expectNoPluginChannel();
  });
}
