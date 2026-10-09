import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/launch/gated_media_engine.dart';
import 'package:one_second_diary/app/launch/media_start_gate.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../../support/support.dart';

/// Also counts the encoder probes, the first ffmpeg call of `init()`.
class _CountingFfmpeg extends FakeFfmpegGateway {
  int encoderProbes = 0;

  @override
  Future<String> listEncoders() {
    encoderProbes++;
    return super.listEncoders();
  }
}

void main() {
  late AppPaths paths;
  late _CountingFfmpeg ffmpeg;
  late MediaStartGate gate;
  late GatedMediaEngine engine;

  setUp(() async {
    paths = await createTestPaths();
    ffmpeg = _CountingFfmpeg();
    gate = MediaStartGate();
    engine = GatedMediaEngine(
      gate: gate,
      ffmpeg: ffmpeg,
      paths: paths,
      logger: memoryLogger(MemoryLogSink()),
      clock: FakeClock(DateTime(2024, 1, 5, 10)),
      loadAsset: (String key) async => ByteData(8),
      isIOS: false,
    );
  });

  /// A probe that ends either way (the fake's output is no real probe).
  Future<void> probe(MediaEngine engine, AppPaths paths) => engine
      .probe('${paths.videos}2024-01-05.mp4')
      .then((_) {}, onError: (Object _) {});

  // No media job, and so no init() (which empties the scratch folder), before
  // the folder migration and the orphan sweep are done.
  test('holds every job, and the scratch sweep, until the launch opens the '
      'gate', () async {
    // What the folder migration staged in scratch.
    final File staged = File('${paths.scratchDir}/migration/staged.mp4')
      ..createSync(recursive: true);
    bool finished = false;
    final Future<void> held = probe(
      engine,
      paths,
    ).whenComplete(() => finished = true);

    // The same job on an ungated engine, started later over other folders:
    // once it is done, an ungated engine here would have swept scratch and
    // reached ffmpeg too.
    final AppPaths otherPaths = await createTestPaths();
    final _CountingFfmpeg otherFfmpeg = _CountingFfmpeg();
    await probe(
      MediaEngine(
        ffmpeg: otherFfmpeg,
        paths: otherPaths,
        logger: memoryLogger(MemoryLogSink()),
        clock: FakeClock(DateTime(2024, 1, 5, 10)),
        loadAsset: (String key) async => ByteData(8),
        isIOS: false,
      ),
      otherPaths,
    );
    await pumpEventQueue();
    expect(otherFfmpeg.encoderProbes, 1);
    expect(otherFfmpeg.probed, hasLength(1));

    expect(finished, isFalse);
    expect(ffmpeg.encoderProbes, 0);
    expect(ffmpeg.probed, isEmpty);
    expect(staged.existsSync(), isTrue);

    gate.open();
    await held;

    expect(finished, isTrue);
    expect(ffmpeg.encoderProbes, 1);
    expect(ffmpeg.probed, hasLength(1));
    expect(
      staged.existsSync(),
      isFalse,
      reason: 'init() empties the scratch folder once the gate is open',
    );
  });
}
