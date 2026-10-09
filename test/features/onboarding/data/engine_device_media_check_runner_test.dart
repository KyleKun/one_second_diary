// The engine's media tests adapted to the phone check's runner: each test
// announced as it starts with its step, the engine's answer keyed the way
// the stored profile wants it, the samples copied from the assets for the
// run, and a cancel answering nothing.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/device_media_check.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/device_media_check_result.dart'
    as engine;
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/onboarding/data/engine_device_media_check_runner.dart';
import 'package:one_second_diary/features/onboarding/domain/device_media_check_runner.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';

import '../../../support/support.dart';

void main() {
  late AppPaths paths;
  late MemoryLogSink log;
  late FakeMediaEngine media;
  late List<String> loaded;

  setUp(() async {
    paths = await createTestPaths();
    log = MemoryLogSink();
    media = FakeMediaEngine(scratchDir: paths.scratchDir);
    loaded = <String>[];
  });

  EngineDeviceMediaCheckRunner runner({
    List<String> samples = const <String>[],
  }) => EngineDeviceMediaCheckRunner(
    engine: media,
    paths: paths,
    loadAsset: (String key) async {
      loaded.add(key);
      if (key.endsWith('missing.mp4')) throw StateError('no such asset');
      return ByteData.sublistView(Uint8List.fromList(fakeVideoBytes));
    },
    logger: memoryLogger(log),
    samples: samples,
  );

  test('counts one step per candidate and per sample, announces each as '
      'it starts with its step over the run, and keys the answer by the '
      'canonical format; a failed candidate has no factor', () async {
    const List<String> samples = <String>['assets/calibration/iphone.mp4'];
    final ClipFormat first = DeviceMediaCheck.candidates.first;
    final ClipFormat second = DeviceMediaCheck.candidates[1];
    media.deviceCheck = engine.DeviceMediaCheckResult(
      encode: <engine.EncodeTestResult>[
        engine.EncodeTestResult(
          format: first,
          encoder: VideoEncoder.libx264,
          ok: true,
          realtimeFactor: 2.5,
        ),
        engine.EncodeTestResult(
          format: second,
          encoder: VideoEncoder.hevcMediaCodec,
          ok: false,
          realtimeFactor: 0,
        ),
      ],
      decode: <engine.DecodeTestResult>[
        engine.DecodeTestResult(
          sample: '${paths.scratchDir}/calibration/iphone.mp4',
          ok: true,
          realtimeFactor: 1.5,
        ),
      ],
    );
    final List<DeviceMediaCheckStep> steps = <DeviceMediaCheckStep>[];

    final EngineDeviceMediaCheckRunner tests = runner(samples: samples);
    expect(tests.stepCount, DeviceMediaCheck.candidates.length + 1);
    final DeviceMediaCheckResult result = await tests
        .start(onStep: steps.add)
        .result;

    expect(result.encode, <String, EncodeResult>{
      first.toString(): const EncodeResult(ok: true, realtimeFactor: 2.5),
      second.toString(): const EncodeResult(ok: false),
    });
    expect(result.decode, <String, double>{'iphone': 1.5});
    expect(steps, <DeviceMediaCheckStep>[
      for (final (int index, ClipFormat format)
          in DeviceMediaCheck.candidates.indexed)
        EncodeStep(index: index, format: format),
      DecodeStep(index: DeviceMediaCheck.candidates.length, sample: 'iphone'),
    ]);
  });

  test('the samples are copied from the assets into scratch for the run '
      'and removed after it; one that cannot be loaded is left out, '
      'logged', () async {
    final EngineDeviceMediaCheckRunner tests = runner(
      samples: const <String>[
        'assets/calibration/iphone.mp4',
        'assets/calibration/missing.mp4',
      ],
    );

    final DeviceMediaCheckResult result = await tests
        .start(onStep: (_) {})
        .result;

    final String copied = '${paths.scratchDir}/calibration/iphone.mp4';
    expect(loaded, <String>[
      'assets/calibration/iphone.mp4',
      'assets/calibration/missing.mp4',
    ]);
    expect(media.checkedSamples, <List<String>>[
      <String>[copied],
    ]);
    expect(File(copied).existsSync(), isFalse, reason: 'removed after');
    expect(result.decode, <String, double>{'iphone': 1.0});
    expect(log.lines, anyElement(contains('[WARNING]')));
  });

  test('without samples nothing is copied, no decode step is announced '
      'and the decode map is empty', () async {
    final List<DeviceMediaCheckStep> steps = <DeviceMediaCheckStep>[];

    final DeviceMediaCheckResult result = await runner()
        .start(onStep: steps.add)
        .result;

    expect(loaded, isEmpty);
    expect(media.checkedSamples, <List<String>>[<String>[]]);
    expect(steps.whereType<DecodeStep>(), isEmpty);
    expect(result.decode, isEmpty);
    expect(result.encode, hasLength(DeviceMediaCheck.candidates.length));
  });

  test('a cancelled run answers nothing', () async {
    final DeviceMediaCheckRun run = runner().start(onStep: (_) {});
    await run.cancel();

    final DeviceMediaCheckResult result = await run.result;

    expect(result.encode, isEmpty);
    expect(result.decode, isEmpty);
  });
}
