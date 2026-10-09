import 'dart:async';

import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/onboarding/domain/device_media_check_runner.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';

/// A [DeviceMediaCheckRunner] that reports one encode step per entry of
/// [encode] (in order) and one decode step per entry of [decode], then
/// answers with them. With [hold] set, the run waits until the test calls
/// [release]; [fail] makes the run throw instead of answering.
final class FakeDeviceMediaCheckRunner implements DeviceMediaCheckRunner {
  FakeDeviceMediaCheckRunner({
    Map<ClipFormat, EncodeResult> encode = const <ClipFormat, EncodeResult>{},
    this.decode = const <String, double>{},
  }) : encode = Map<ClipFormat, EncodeResult>.of(encode);

  final Map<ClipFormat, EncodeResult> encode;
  final Map<String, double> decode;

  bool hold = false;
  bool fail = false;

  /// Every run started, newest last.
  final List<FakeDeviceMediaCheckRun> runs = <FakeDeviceMediaCheckRun>[];

  /// Lets every held run answer.
  void release() {
    for (final FakeDeviceMediaCheckRun run in runs) {
      run._release();
    }
  }

  @override
  int get stepCount => encode.length + decode.length;

  @override
  DeviceMediaCheckRun start({
    required void Function(DeviceMediaCheckStep step) onStep,
  }) {
    final FakeDeviceMediaCheckRun run = FakeDeviceMediaCheckRun._(this, onStep);
    runs.add(run);
    unawaited(run._go());
    return run;
  }

  /// The canonical 1080p30 H.264 candidate, landscape.
  static ClipFormat format({
    ResolutionTier tier = ResolutionTier.p1080,
    VideoCodec codec = VideoCodec.h264,
    FrameRate fps = FrameRate.f30,
  }) => ClipFormat(
    tier: tier,
    orientation: VideoOrientation.landscape,
    codec: codec,
    fps: fps,
    channels: AudioChannels.mono,
    range: DynamicRange.sdr,
  );
}

final class FakeDeviceMediaCheckRun implements DeviceMediaCheckRun {
  FakeDeviceMediaCheckRun._(this._runner, this._onStep);

  final FakeDeviceMediaCheckRunner _runner;
  final void Function(DeviceMediaCheckStep step) _onStep;
  final Completer<DeviceMediaCheckResult> _result =
      Completer<DeviceMediaCheckResult>();
  final Completer<void> _gate = Completer<void>();

  bool cancelled = false;

  void _release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  Future<void> _go() async {
    await Future<void>.delayed(Duration.zero);
    int index = 0;
    for (final ClipFormat format in _runner.encode.keys) {
      if (cancelled) break;
      _onStep(EncodeStep(index: index++, format: format));
    }
    for (final String sample in _runner.decode.keys) {
      if (cancelled) break;
      _onStep(DecodeStep(index: index++, sample: sample));
    }
    if (_runner.hold) await _gate.future;
    if (_runner.fail) {
      _result.completeError(StateError('the engine could not run'));
      return;
    }
    _result.complete(
      DeviceMediaCheckResult(
        encode: <String, EncodeResult>{
          for (final MapEntry<ClipFormat, EncodeResult> entry
              in _runner.encode.entries)
            entry.key.toString(): entry.value,
        },
        decode: _runner.decode,
      ),
    );
  }

  @override
  Future<DeviceMediaCheckResult> get result => _result.future;

  @override
  Future<void> cancel() async {
    cancelled = true;
    _release();
  }
}
