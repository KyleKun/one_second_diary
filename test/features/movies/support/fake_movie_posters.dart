import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_ticket.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';

/// One poster asked of [FakeMoviePosters] and not served from its cache.
final class FakePosterRequest {
  FakePosterRequest(this.file, this.orientation);

  /// The movie's path in `Movies/`.
  final String file;
  final VideoOrientation? orientation;
  final Completer<String?> _file = Completer<String?>();
  bool cancelled = false;

  /// The poster is made at [path].
  void make(String path) => _file.complete(path);

  /// The poster could not be made.
  void fail() => _file.complete(null);
}

/// A [MoviePosters] whose posters are [known] (by path in `Movies/`) or
/// made by the test ([requests]).
class FakeMoviePosters extends Fake implements MoviePosters {
  final Map<String, String> known = <String, String>{};
  final List<FakePosterRequest> requests = <FakePosterRequest>[];

  /// The requests still waiting and wanted.
  List<FakePosterRequest> get pending => <FakePosterRequest>[
    for (final FakePosterRequest request in requests)
      if (!request._file.isCompleted && !request.cancelled) request,
  ];

  @override
  String? cachedFile(String file, {VideoOrientation? orientation}) =>
      known[file];

  @override
  ThumbnailTicket request(String file, {VideoOrientation? orientation}) {
    final String? made = known[file];
    if (made != null) {
      return ThumbnailTicket(
        file: Future<String?>.value(made),
        onCancel: () {},
      );
    }
    final FakePosterRequest request = FakePosterRequest(file, orientation);
    requests.add(request);
    return ThumbnailTicket(
      file: request._file.future,
      onCancel: () => request.cancelled = true,
    );
  }
}
