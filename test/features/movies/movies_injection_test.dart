import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/platform/wakelock_gateway.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/features/movies/data/movie_tag_reader.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/movie_player_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_cubit.dart';

import '../../shared/harness/test_container.dart';
import '../../support/support.dart';

void main() {
  late TestContainer container;

  setUp(() async {
    container = await TestContainer.create();
  });

  tearDown(() => container.dispose());

  test('one movie job for the whole app, idle at first, so a movie goes on '
      'while the flow is left; each Create movie flow and each visit to My '
      "movies gets its own cubit, the posters' queue and the tag reader are "
      "the app's", () {
    final MovieJobBloc job = sl<MovieJobBloc>();
    expect(sl<MovieJobBloc>(), same(job));
    expect(job.state, const MovieJobState.idle());

    const MovieSource january = MovieSource.month(year: 2024, month: 1);
    final CreateMovieCubit flow = sl<CreateMovieCubit>(
      param1: const CreateMovieArgs(source: january),
    );
    expect(flow.state.source, january);
    expect(
      sl<CreateMovieCubit>(param1: const CreateMovieArgs()),
      isNot(same(flow)),
    );

    expect(sl<MyMoviesCubit>(), isNot(same(sl<MyMoviesCubit>())));
    expect(sl<MoviePosters>(), same(sl<MoviePosters>()));
    expect(sl<MovieTagReader>(), same(sl<MovieTagReader>()));
  });

  test('the job and the player keep the screen on through one shared '
      'wakelock: the player pausing never lets the phone sleep while a movie '
      'is made', () async {
    // The app's one hold (the job takes it too), over the platform's.
    final WakelockGateway shared = sl<WakelockGateway>();
    final FakeWakelockGateway platform = container.gateways.wakelock;

    await shared.enable();
    final MoviePlayerCubit player = sl<MoviePlayerCubit>(param1: 'a.mp4')
      ..playingChanged(playing: true);
    await pumpEventQueue();
    player.playingChanged(playing: false);
    await pumpEventQueue();

    expect(platform.enabled, isTrue);
    await player.close();
    await shared.disable();
    expect(platform.enabled, isFalse);
  });
}
