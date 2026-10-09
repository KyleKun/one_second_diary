// The Journey tab, as the user meets it: a movie being made takes the
// place of "Create movie" with how far it got, and a tap opens the
// making-movie page, where it goes on. The stats are the JourneyCubit's,
// pinned in journey_cubit_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_cubit.dart';
import 'package:one_second_diary/features/journey/presentation/pages/journey_page.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_movie_hero.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_movie_job_card.dart';
import 'package:one_second_diary/features/movies/domain/movie_build_event.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_event.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

import '../../../../shared/harness/settle.dart';
import '../../../movies/support/pump_localized_osd.dart';
import '../../support/journey_world.dart';

void main() {
  late JourneyWorld world;

  setUp(() => world = JourneyWorld());
  tearDown(() => world.dispose());

  testWidgets('"Create movie" gives way to the movie being made, with how '
      'far it is; a tap opens M6, where it goes on', (
    WidgetTester tester,
  ) async {
    const Key makingKey = Key('makingMovie');
    world.recordDays(<LocalDay>[
      for (int day = 25; day <= 28; day++) LocalDay(2026, 9, day),
    ]);
    final JourneyCubit cubit = world.cubit();
    final GoRouter router = GoRouter(
      initialLocation: AppRoute.journey.path,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.journey.path,
          builder: (BuildContext context, GoRouterState state) =>
              Scaffold(body: world.wrap(cubit, const JourneyPage())),
        ),
        GoRoute(
          path: AppRoute.makingMovie.path,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: SizedBox.expand(key: makingKey)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpLocalizedOsd(tester, const SizedBox.shrink(), router: router);
    expect(find.byKey(JourneyMovieHero.createMovieKey), findsOneWidget);
    final MovieJobBloc job = tester
        .element(find.byType(JourneyPage))
        .read<MovieJobBloc>();

    job.add(
      const MovieJobStarted(
        MovieJobRequest(
          source: MovieSource.month(year: 2026, month: 9),
          profile: ProfileKey.defaultProfile,
          format: ClipFormat.legacy(VideoOrientation.landscape),
          title: 'September 2026',
        ),
      ),
    );
    await tester.pump();
    world.movieBuilder
      ..emit(
        MovieBuildStarted(<ClipRef>[
          for (int day = 25; day <= 28; day++)
            ClipRef(
              profile: ProfileKey.defaultProfile,
              relPath: '${LocalDay(2026, 9, day).fileStem}.mp4',
            ),
        ]),
      )
      ..emit(const MovieBuildProgress(MoviePreparing(index: 2, total: 4)));
    await tester.pump();
    await tester.pump(OsdMotion.standard);

    expect(find.byKey(JourneyMovieHero.createMovieKey), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(JourneyMovieJobCard.percentKey)).data,
      '50%',
    );

    await tester.tap(find.byKey(JourneyMovieJobCard.cardKey));
    await settle(tester);

    expect(find.byKey(makingKey), findsOneWidget);
    expect(job.state.isRunning, isTrue);
  });
}
