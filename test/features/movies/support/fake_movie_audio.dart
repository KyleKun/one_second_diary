import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/features/movies/data/movie_audio.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';

/// A [MovieAudio] that swaps at once: every [toggle] is recorded in
/// [toggled]; with [failNext] the next one throws instead.
class FakeMovieAudio extends Fake implements MovieAudio {
  final List<MovieEntry> toggled = <MovieEntry>[];
  bool failNext = false;

  @override
  Future<MovieEntry> toggle(MovieEntry movie) async {
    toggled.add(movie);
    if (failNext) {
      failNext = false;
      throw const VideoProcessingException('swap', returnCode: 1, logTail: '');
    }
    final bool? on = movie.musicOn;
    return on == null ? movie : movie.withMusicOn(on: !on);
  }
}
