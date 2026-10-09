// "Create movie" checks the phone's free space before the movie job starts.
// The rest of the page is pinned by CreateMovieCubit's tests and the
// confirm-movie journey.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_state.dart';
import 'package:one_second_diary/features/movies/presentation/pages/confirm_movie_page.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

import '../../../../shared/harness/settle.dart';
import '../../../../theme/support/load_osd_fonts.dart';
import '../../support/create_movie_world.dart';
import '../../support/pump_localized_osd.dart';

void main() {
  late CreateMovieWorld world;

  setUpAll(loadOsdFonts);
  setUp(() => world = CreateMovieWorld());
  tearDown(() => world.dispose());

  testWidgets('Create movie waits for the free space, the button spinning '
      'after 150 ms, then M6 opens', (WidgetTester tester) async {
    const Key making = ValueKey<AppRoute>(AppRoute.makingMovie);
    world
      ..record(<LocalDay>[
        for (int day = 1; day <= 28; day++) LocalDay(2026, 9, day),
      ])
      ..freeSpace.free = 64000000000
      ..freeSpace.hold = true;
    final CreateMovieCubit flow = world.cubit(
      source: const MovieSource.month(year: 2026, month: 9),
    );
    addTearDown(flow.close);
    final GoRouter router = GoRouter(
      initialLocation: AppRoute.confirmMovie.path,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.confirmMovie.path,
          builder: (BuildContext context, GoRouterState state) =>
              const ConfirmMoviePage(),
        ),
        GoRoute(
          path: AppRoute.makingMovie.path,
          builder: (BuildContext context, GoRouterState state) =>
              const SizedBox(key: making),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpLocalizedOsd(
      tester,
      const SizedBox.shrink(),
      router: router,
      above: (Widget app) => world.above(
        BlocProvider<CreateMovieCubit>.value(value: flow, child: app),
      ),
    );

    await tester.tap(find.byKey(ConfirmMoviePage.createKey));
    await tester.pump(OsdMotion.loadingDelay);
    await tester.pump();

    expect(flow.state.launch, MovieLaunch.checking);
    expect(
      tester
          .widget<PrimaryButton>(find.byKey(ConfirmMoviePage.createKey))
          .loading,
      isTrue,
    );
    expect(find.byKey(making), findsNothing);

    world.freeSpace.answer();
    await settle(tester);
    expect(find.byKey(making), findsOneWidget);
  });
}
