import 'dart:async';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/features/movies/data/movie_tag_reader.dart';
import 'package:one_second_diary/features/movies/domain/movie_tags.dart';

/// A [MovieTagSource] that answers [answers] by absolute path; any other
/// file can't be probed (a `VideoProcessingException`, as the engine
/// throws). With [hold], every read waits for [release].
class FakeMovieTagSource implements MovieTagSource {
  final Map<String, MovieTags> answers = <String, MovieTags>{};

  /// The paths read, in order.
  final List<String> read = <String>[];

  bool hold = false;
  final List<Completer<void>> _held = <Completer<void>>[];

  /// Lets every held read answer.
  void release() {
    for (final Completer<void> gate in _held) {
      gate.complete();
    }
    _held.clear();
  }

  @override
  Future<MovieTags> tagsOf(String path) async {
    read.add(path);
    if (hold) {
      final Completer<void> gate = Completer<void>();
      _held.add(gate);
      await gate.future;
    }
    return answers[path] ??
        (throw VideoProcessingException(
          'No probe for $path',
          returnCode: 1,
          logTail: 'Invalid data found when processing input',
        ));
  }
}
