// The movie being made, drawn from the app's movie job only: the grid of
// its clips with the one in hand ringed, the count and the percent, the
// bar, "Keep the app open", and Cancel, which asks first and really stops.
// Done hands over to the movie-created page; a failure says why and offers
// Try again, Report error and Close.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/domain/movie_build_event.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_event.dart';
import 'package:one_second_diary/features/movies/presentation/pages/making_movie_page.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/making_movie_count.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/report_error_cubit.dart';

import '../../../../shared/fakes/fake_bug_reports.dart';
import '../../../../shared/harness/settle.dart';
import '../../../../shared/widgets/support/osd_widget_harness.dart';
import '../../../../theme/support/load_osd_fonts.dart';
import '../../support/create_movie_world.dart';
import '../../support/pump_localized_osd.dart';

const ProfileKey _default = ProfileKey.defaultProfile;
const Key _confirm = ValueKey<AppRoute>(AppRoute.confirmMovie);
const Key _making = ValueKey<AppRoute>(AppRoute.makingMovie);
const Key _created = ValueKey<AppRoute>(AppRoute.movieCreated);

/// The first [count] days of September 2026, a clip each.
List<LocalDay> _days(int count) => <LocalDay>[
  for (int day = 0; day < count; day++) LocalDay(2026, 9, 1).addDays(day),
];

List<ClipRef> _clipsOf(List<LocalDay> days) => <ClipRef>[
  for (final LocalDay day in days)
    ClipRef(profile: _default, relPath: '${day.fileStem}.mp4'),
];

const MovieJobRequest _request = MovieJobRequest(
  source: MovieSource.month(year: 2026, month: 9),
  profile: _default,
  format: ClipFormat.legacy(VideoOrientation.landscape),
  title: 'September 2026',
  clipBytes: 200,
);

void main() {
  late CreateMovieWorld world;
  late FakeBugReports reports;
  late GoRouter router;

  setUpAll(loadOsdFonts);
  setUp(() {
    world = CreateMovieWorld();
    reports = FakeBugReports();
  });
  tearDown(() => world.dispose());

  /// The confirm page (a stub), with the page pushed on it once a test
  /// starts a job; the movie-created page is a stub.
  Future<void> pumpFlow(
    WidgetTester tester, {
    Size size = kOsdFrame,
    bool disableAnimations = false,
    double textScale = 1,
    Brightness brightness = Brightness.dark,
    AppLanguage language = AppLanguage.en,
  }) async {
    router = GoRouter(
      initialLocation: AppRoute.confirmMovie.path,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.confirmMovie.path,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: SizedBox.expand(key: _confirm)),
        ),
        GoRoute(
          path: AppRoute.makingMovie.path,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              OsdPages.fadeThrough(
                state,
                BlocProvider<ReportErrorCubit>(
                  create: (_) => ReportErrorCubit(reports: reports),
                  child: const MakingMoviePage(key: _making),
                ),
              ),
        ),
        GoRoute(
          path: AppRoute.movieCreated.path,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: SizedBox.expand(key: _created)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpLocalizedOsd(
      tester,
      const SizedBox.shrink(),
      router: router,
      above: world.above,
      size: size,
      disableAnimations: disableAnimations,
      textScale: textScale,
      brightness: brightness,
      language: language,
    );
  }

  MovieJobBloc jobOf(WidgetTester tester) =>
      tester.element(find.byType(Navigator).first).read<MovieJobBloc>();

  /// The movie of the first [clips] days starts (the confirm page's Create
  /// movie) and the page opens.
  Future<List<ClipRef>> start(WidgetTester tester, {int clips = 4}) async {
    final List<LocalDay> days = _days(clips);
    world.record(days);
    jobOf(tester).add(const MovieJobStarted(_request));
    await tester.pump();
    world.movieBuilder.emit(MovieBuildStarted(_clipsOf(days)));
    unawaited(router.push<void>(AppRoute.makingMovie.path));
    await settle(tester);
    return _clipsOf(days);
  }

  Future<void> emit(WidgetTester tester, MovieBuildEvent event) async {
    world.movieBuilder.emit(event);
    await settle(tester);
  }

  testWidgets('screen readers hear the progress every 10 %: the percent and '
      'the clips done', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpFlow(tester);
    await start(tester, clips: 20);

    String announced() =>
        tester.getSemantics(find.byKey(MakingMovieCount.rowKey)).label;
    expect(
      announced(),
      Strings.makingMovieProgressSemantics(20, done: 0, percent: '0%'),
    );

    await emit(
      tester,
      const MovieBuildProgress(MoviePreparing(index: 1, total: 20)),
    );
    expect(
      announced(),
      Strings.makingMovieProgressSemantics(20, done: 0, percent: '0%'),
      reason: '5 % is not worth saying',
    );

    await emit(
      tester,
      const MovieBuildProgress(MoviePreparing(index: 5, total: 20)),
    );
    expect(
      announced(),
      Strings.makingMovieProgressSemantics(20, done: 5, percent: '25%'),
    );
    expect(
      tester
          .getSemantics(find.byKey(MakingMovieCount.rowKey))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    semantics.dispose();
  });
}
