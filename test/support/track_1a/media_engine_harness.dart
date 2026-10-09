import 'dart:convert';
import 'dart:typed_data';

import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/ffmpeg_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../fake_clock.dart';
import '../memory_log_sink.dart';

/// A bundled asset as small bytes spelling its key, as `rootBundle.load`
/// would hand it over.
Future<ByteData> fakeAsset(String key) async =>
    ByteData.sublistView(Uint8List.fromList(utf8.encode(key)));

/// A [MediaEngine] over [ffmpeg] and [paths], with a pinned clock and a
/// memory log unless given.
MediaEngine engineOver({
  required FfmpegGateway ffmpeg,
  required AppPaths paths,
  MemoryLogSink? log,
  Clock? clock,
  bool isIOS = false,
  Future<ByteData> Function(String key) loadAsset = fakeAsset,
}) {
  final Clock time = clock ?? FakeClock(DateTime(2024, 1, 5, 10));
  return MediaEngine(
    ffmpeg: ffmpeg,
    paths: paths,
    logger: memoryLogger(log ?? MemoryLogSink(), clock: time),
    clock: time,
    loadAsset: loadAsset,
    isIOS: isIOS,
  );
}
