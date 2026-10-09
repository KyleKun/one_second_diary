import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/thumbnail_gateway.dart';

/// One call to [FakeThumbnailGateway.writeThumbnail].
final class ThumbnailRequest extends Equatable {
  const ThumbnailRequest({
    required this.videoPath,
    required this.outputPath,
    required this.maxWidth,
    required this.maxHeight,
    required this.quality,
    required this.timeMs,
  });

  final String videoPath;
  final String outputPath;
  final int maxWidth;
  final int maxHeight;
  final int quality;
  final int timeMs;

  @override
  List<Object?> get props => <Object?>[
    videoPath,
    outputPath,
    maxWidth,
    maxHeight,
    quality,
    timeMs,
  ];
}

/// A [ThumbnailGateway] that writes a few JPEG bytes to the output path.
///
/// An output path not ending in `.jpg` throws an
/// [ArgumentError], and the parent folder is created. Records every call in
/// [requests]. Videos in [failingVideos] return null.
/// With [holdRequests], calls stay in flight ([inFlight]) until
/// [completePending], so tests can check bounded concurrency and ordering.
class FakeThumbnailGateway extends Fake implements ThumbnailGateway {
  /// The bytes written for every thumbnail (a JPEG start marker).
  static const List<int> jpegBytes = <int>[0xFF, 0xD8, 0xFF, 0xE0];

  final List<ThumbnailRequest> requests = <ThumbnailRequest>[];
  final Set<String> failingVideos = <String>{};
  bool holdRequests = false;

  final List<Completer<void>> _pending = <Completer<void>>[];

  /// Requests started and not finished yet.
  int get inFlight => _pending.length;

  /// Lets the oldest [count] held requests finish (all when null).
  void completePending({int? count}) {
    final List<Completer<void>> released = _pending
        .take(count ?? _pending.length)
        .toList();
    _pending.removeRange(0, released.length);
    for (final Completer<void> gate in released) {
      gate.complete();
    }
  }

  @override
  Future<String?> writeThumbnail({
    required String videoPath,
    required String outputPath,
    required int maxWidth,
    required int maxHeight,
    required int quality,
    required int timeMs,
  }) async {
    if (!outputPath.endsWith('.jpg')) {
      throw ArgumentError.value(outputPath, 'outputPath', 'must end in .jpg');
    }
    requests.add(
      ThumbnailRequest(
        videoPath: videoPath,
        outputPath: outputPath,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
        timeMs: timeMs,
      ),
    );
    if (holdRequests) {
      final Completer<void> gate = Completer<void>();
      _pending.add(gate);
      await gate.future;
    }
    if (failingVideos.contains(videoPath)) return null;
    final File output = File(outputPath);
    await output.parent.create(recursive: true);
    await output.writeAsBytes(jpegBytes);
    return outputPath;
  }
}
