import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clip_editor/data/filmstrip_frames.dart';

/// One request to [FakeFilmstripFrames.of].
final class FilmstripRequest extends Equatable {
  const FilmstripRequest({
    required this.path,
    required this.durationMs,
    required this.count,
    required this.width,
    required this.height,
    required this.order,
  });

  final String path;
  final int durationMs;
  final int count;
  final int width;
  final int height;

  /// The tiles asked for, in the order they are wanted.
  final List<int> order;

  @override
  List<Object?> get props => <Object?>[
    path,
    durationMs,
    count,
    width,
    height,
    order,
  ];
}

/// A [FilmstripFrames] whose frames the test makes: every request is kept
/// in [requests], and [make] sends frame `index` of the latest one (at
/// `/frames/<index>.jpg`). [cancelled] counts the requests nobody listens to
/// any more; [disposed] says whether the editor let it go.
class FakeFilmstripFrames extends Fake implements FilmstripFrames {
  final List<FilmstripRequest> requests = <FilmstripRequest>[];
  final List<StreamController<FilmstripFrame>> _streams =
      <StreamController<FilmstripFrame>>[];
  int cancelled = 0;
  bool disposed = false;

  @override
  Stream<FilmstripFrame> of(
    String path, {
    required int durationMs,
    required int count,
    required int width,
    required int height,
    Iterable<int>? order,
  }) {
    requests.add(
      FilmstripRequest(
        path: path,
        durationMs: durationMs,
        count: count,
        width: width,
        height: height,
        order: List<int>.of(order ?? List<int>.generate(count, (int i) => i)),
      ),
    );
    final StreamController<FilmstripFrame> stream =
        StreamController<FilmstripFrame>(onCancel: () => cancelled++);
    _streams.add(stream);
    return stream.stream;
  }

  /// Sends frame [index] of the latest request.
  void make(int index) => _streams.last.add(
    FilmstripFrame(index: index, path: '/frames/$index.jpg'),
  );

  /// Every single frame asked for, in order; complete its
  /// `answer` with the frame's path, or null when it can't be made.
  final List<FrameRequest> frameRequests = <FrameRequest>[];

  @override
  Future<String?> frameAt(
    String path, {
    required int timeMs,
    required int width,
    required int height,
  }) {
    final FrameRequest request = FrameRequest(
      path: path,
      timeMs: timeMs,
      width: width,
      height: height,
    );
    frameRequests.add(request);
    return request.answer.future;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

/// One request to [FakeFilmstripFrames.frameAt].
final class FrameRequest {
  FrameRequest({
    required this.path,
    required this.timeMs,
    required this.width,
    required this.height,
  });

  final String path;
  final int timeMs;
  final int width;
  final int height;

  /// Completes the request.
  final Completer<String?> answer = Completer<String?>();
}
