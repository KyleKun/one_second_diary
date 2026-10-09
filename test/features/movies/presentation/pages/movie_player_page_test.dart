// The movie player (/movies/play?file=), always dark: the movie full width
// on black, playing at once with sound, tap to pause, the bar to seek, and
// the screen kept on while it plays.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/movie_player_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/pages/movie_player_page.dart';
import 'package:one_second_diary/features/movies/presentation/sheets/movie_chapters_sheet.dart';
import 'package:one_second_diary/shared/widgets/buttons/play_overlay_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/viewer_top_bar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_forced_dark.dart';

import '../../../../shared/harness/settle.dart';
import '../../../../shared/widgets/support/osd_widget_harness.dart';
import '../../../../support/support.dart';
import '../../../../theme/support/load_osd_fonts.dart';
import '../../support/my_movies_world.dart';
import '../../support/pump_localized_osd.dart';

final MovieEntry _kids = madeMovie(1, title: '2025', profile: kids, clips: 120);

/// Three clips of a second and a half each.
const List<MovieChapter> _chapters = <MovieChapter>[
  MovieChapter(startMs: 0, endMs: 1500, title: 'Aug 1, 2026'),
  MovieChapter(startMs: 1500, endMs: 3000, title: 'Aug 2, 2026 · Berlin'),
  MovieChapter(startMs: 3000, endMs: 4500, title: 'Aug 3, 2026'),
];

/// A movie made by this version, with its chapters and a tag filter.
final MovieEntry _trip = MovieEntry(
  fileName: 'OSD-Movie-2-2026-09-02.mp4',
  title: 'Trip',
  profile: null,
  clipCount: 3,
  from: null,
  to: null,
  createdAt: DateTime(2026, 9, 2, 20),
  durationMs: 4500,
  tags: const <String>['trip'],
  chapters: _chapters,
);

void main() {
  late MyMoviesWorld world;
  late FakePlayerFactory players;
  late FakeWakelockGateway wakelock;
  late GoRouter router;

  setUpAll(loadOsdFonts);
  setUp(() {
    world = MyMoviesWorld();
    world.movies.movies.add(_kids);
    players = FakePlayerFactory()..duration = const Duration(seconds: 90);
    wakelock = FakeWakelockGateway();
  });
  tearDown(() => world.dispose());

  /// Journey (showing [origin] in its middle) with the player of [file]
  /// pushed over it, built as its route builds it; settled unless
  /// [settleAfterPush] is false (the flight is then under way).
  Future<void> pumpPlayer(
    WidgetTester tester, {
    String? file,
    double textScale = 1,
    bool disableAnimations = false,
    Brightness brightness = Brightness.dark,
    Size size = kOsdFrame,
    Widget? origin,
    bool settleAfterPush = true,
  }) async {
    router = GoRouter(
      initialLocation: AppRoute.journey.path,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.journey.path,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              OsdPages.material(
                state,
                Scaffold(
                  body: Stack(
                    children: <Widget>[
                      const SizedBox.expand(key: MyMoviesWorld.journeyKey),
                      ?origin,
                    ],
                  ),
                ),
              ),
        ),
        GoRoute(
          path: AppRoute.moviePlayer.path,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              OsdPages.mediaFlight(
                state,
                OsdForcedDark(
                  child: MultiRepositoryProvider(
                    providers: [
                      RepositoryProvider<PlayerPool>(
                        create: (_) => PlayerPool(
                          factory: players,
                          logger: memoryLogger(world.log),
                          muted: false,
                        ),
                        dispose: (PlayerPool pool) => unawaited(pool.dispose()),
                      ),
                      RepositoryProvider<MoviePosters>.value(
                        value: world.posters,
                      ),
                    ],
                    child: BlocProvider<MoviePlayerCubit>(
                      create: (_) => MoviePlayerCubit(
                        file: state
                            .uri
                            .queryParameters[AppRoute.movieFileParameter]!,
                        movies: world.movies,
                        wakelock: wakelock,
                        logger: memoryLogger(world.log),
                      ),
                      child: const MoviePlayerPage(
                        key: ValueKey<AppRoute>(AppRoute.moviePlayer),
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpLocalizedOsd(
      tester,
      const SizedBox.shrink(),
      router: router,
      above: (Widget app) => RepositoryProvider<AppPaths>.value(
        value: world.paths,
        child: world.above(app),
      ),
      textScale: textScale,
      disableAnimations: disableAnimations,
      brightness: brightness,
      size: size,
    );
    MoviePlayerArgs(
      file: file ?? _kids.fileName,
    ).push<void>(tester.element(find.byKey(MyMoviesWorld.journeyKey))).ignore();
    if (settleAfterPush) {
      await settle(tester);
    } else {
      await tester.pump();
    }
  }

  FakePlayerHandle player() => players.created.last;

  PlayOverlayButton playButton(WidgetTester tester) =>
      tester.widget<PlayOverlayButton>(find.byType(PlayOverlayButton));

  /// The chapter under the title; null for a movie without chapters.
  String? chapterLine(WidgetTester tester) {
    final Finder line = find.descendant(
      of: find.byKey(MoviePlayerPage.chapterKey),
      matching: find.byType(Text),
    );
    return line.evaluate().isEmpty ? null : tester.widget<Text>(line.last).data;
  }

  OsdListRow chapterRow(WidgetTester tester, int index) =>
      tester.widget<OsdListRow>(find.byKey(MovieChaptersSheet.rowKey(index)));

  testWidgets('at the end the replay circle shows; a tap plays it from the '
      'start', (WidgetTester tester) async {
    await pumpPlayer(tester);
    player().emit(
      const PlayerState(
        initialized: true,
        playing: false,
        position: Duration(seconds: 90),
        duration: Duration(seconds: 90),
        error: null,
        aspectRatio: 16 / 9,
        completed: true,
      ),
    );
    await settle(tester);
    expect(playButton(tester).ended, isTrue);

    await tester.tap(find.byKey(MoviePlayerPage.screenKey));
    await settle(tester);

    expect(player().value.value.position, Duration.zero);
    expect(player().value.value.playing, isTrue);
  });

  testWidgets('a movie with chapters shows the chapter playing under its '
      'title and offers Chapters: the sheet lists them with their length, '
      'the one playing checked, and a tap jumps the movie to that chapter '
      'and plays on', (WidgetTester tester) async {
    world.movies.movies.add(_trip);
    await pumpPlayer(tester, file: _trip.fileName);
    expect(chapterLine(tester), 'Aug 1, 2026');
    expect(
      tester.widget<ViewerTopBar>(find.byType(ViewerTopBar)).subtitle,
      isNull,
    );

    await tester.tap(find.byKey(MoviePlayerPage.chaptersKey));
    await settle(tester);
    expect(find.byKey(MovieChaptersSheet.listKey), findsOneWidget);
    expect(chapterRow(tester, 0).trailing, const OsdRowTrailing.check());
    expect(chapterRow(tester, 2).trailing, const OsdRowTrailing.none());
    expect(chapterRow(tester, 2).title, 'Aug 3, 2026');
    expect(chapterRow(tester, 2).value, '0:01');

    await tester.tap(find.byKey(MovieChaptersSheet.rowKey(2)));
    await settle(tester);
    expect(find.byKey(MovieChaptersSheet.listKey), findsNothing);
    expect(player().value.value.position, const Duration(milliseconds: 3000));
    expect(player().value.value.playing, isTrue);
    expect(chapterLine(tester), 'Aug 3, 2026');
  });

  testWidgets('a movie made by an older install has no chapters: its clips '
      'and length under the title and no Chapters button', (
    WidgetTester tester,
  ) async {
    await pumpPlayer(tester);
    expect(chapterLine(tester), isNull);
    expect(find.byKey(MoviePlayerPage.chaptersKey), findsNothing);
    expect(
      tester.widget<ViewerTopBar>(find.byType(ViewerTopBar)).subtitle,
      '120 clips · 3:00',
    );
  });
}
