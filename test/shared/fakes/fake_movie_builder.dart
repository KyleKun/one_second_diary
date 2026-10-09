import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_music.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/features/movies/data/movie_builder.dart';
import 'package:one_second_diary/features/movies/domain/movie_build_event.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// What [FakeMovieBuilder.build] was asked to make.
typedef MovieBuildRequest = ({
  MovieSource source,
  ProfileKey profile,
  ClipFormat format,
  String title,
  CancelToken? cancelToken,
});

/// A [MovieBuilder] the test drives: every `build` records its request in
/// [requests] and returns a stream the test feeds with [emit], ends with
/// [fail] or [finish]. Cancelling the build's token ends it with the
/// builder's `CancelledException`, as the real one does, unless
/// [ignoreCancel].
class FakeMovieBuilder extends Fake implements MovieBuilder {
  final List<MovieBuildRequest> requests = <MovieBuildRequest>[];

  /// Whether each build of [requests] was to include the private clips.
  final List<bool> includedPrivate = <bool>[];

  /// The transition (and the older-clips choice) of each build.
  final List<({MovieTransition? transition, bool upgradeOlderClips})>
  transitions = <({MovieTransition? transition, bool upgradeOlderClips})>[];

  /// The music of each build (null for none).
  final List<MovieMusic?> music = <MovieMusic?>[];
  StreamController<MovieBuildEvent>? _events;

  /// Keeps a cancelled build running (a cancel that lands as it ends).
  bool ignoreCancel = false;

  bool get building => _events != null && !_events!.isClosed;

  CancelToken? get lastToken => requests.last.cancelToken;

  @override
  Stream<MovieBuildEvent> build({
    required MovieSource source,
    required ProfileKey profile,
    required ClipFormat format,
    required String title,
    bool includePrivate = false,
    MovieTransition? transition,
    bool upgradeOlderClips = false,
    MovieMusic? music,
    CancelToken? cancelToken,
  }) {
    includedPrivate.add(includePrivate);
    this.music.add(music);
    transitions.add((
      transition: transition,
      upgradeOlderClips: upgradeOlderClips,
    ));
    requests.add((
      source: source,
      profile: profile,
      format: format,
      title: title,
      cancelToken: cancelToken,
    ));
    final StreamController<MovieBuildEvent> events =
        StreamController<MovieBuildEvent>();
    _events = events;
    unawaited(
      cancelToken?.whenCancelled.then((_) {
        if (ignoreCancel || events.isClosed) return;
        events.addError(const CancelledException('Cancelled'));
        unawaited(events.close());
      }),
    );
    return events.stream;
  }

  /// The running build reports [event].
  void emit(MovieBuildEvent event) => _events!.add(event);

  /// The running build fails with [error].
  Future<void> fail(Object error) async {
    _events!.addError(error);
    await _events!.close();
  }

  /// The running build's stream ends (after its `MovieBuilt`).
  Future<void> finish() => _events!.close();
}
