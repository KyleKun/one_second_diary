import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/device_media_check.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/device_media_check_result.dart'
    as check;
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/onboarding/domain/device_media_check_runner.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';
import 'package:one_second_diary/features/profiles/domain/quality_rules.dart';

/// The bundled decode samples of the phone check, as asset keys under `assets/calibration/`: real-world recordings
/// the check decodes in software to see what this phone plays: a 4K60 H.264 recording and a 4K30 HEVC 10-bit HLG
/// one (an HDR10+ recording converted to HLG).
const List<String> calibrationSamples = <String>[
  'assets/calibration/${QualityRules.h264DecodeSample}.mp4',
  'assets/calibration/${QualityRules.hlgDecodeSample}.mp4',
];

/// The media tests of the phone check over the engine
/// (`MediaEngine.checkDevice`): the synthetic encodes in escalation order,
/// then the software decode of each bundled sample, copied from the
/// assets into scratch for the run and removed after it.
///
/// Encode results are keyed by the candidate's canonical string, decode
/// results by the sample's name (its file name without the extension),
/// as `DeviceMediaProfile` stores them. A cancelled run answers an empty
/// result: the phone check discards it anyway.
final class EngineDeviceMediaCheckRunner implements DeviceMediaCheckRunner {
  EngineDeviceMediaCheckRunner({
    required this.engine,
    required this.paths,
    required this.loadAsset,
    required this.logger,
    List<String> samples = calibrationSamples,
  }) : _samples = List<String>.unmodifiable(samples);

  final MediaEngine engine;
  final AppPaths paths;

  /// Reads a bundled asset (`rootBundle.load` in the app).
  final Future<ByteData> Function(String assetKey) loadAsset;
  final AppLogger logger;
  final List<String> _samples;

  static const String _tag = 'PHONE_CHECK';

  @override
  int get stepCount => DeviceMediaCheck.candidates.length + _samples.length;

  @override
  DeviceMediaCheckRun start({
    required void Function(DeviceMediaCheckStep step) onStep,
  }) {
    final CancelToken token = CancelToken();
    return _Run(result: _run(token, onStep), token: token);
  }

  Future<DeviceMediaCheckResult> _run(
    CancelToken token,
    void Function(DeviceMediaCheckStep step) onStep,
  ) async {
    final List<String> samples = await _copySamples();
    try {
      final check.DeviceMediaCheckResult found = await engine.checkDevice(
        decodeSamples: samples,
        cancelToken: token,
        onEncodeStart: (int index, ClipFormat format) =>
            onStep(EncodeStep(index: index, format: format)),
        onDecodeStart: (int index, String sample) =>
            onStep(DecodeStep(index: index, sample: _nameOf(sample))),
      );
      return DeviceMediaCheckResult(
        encode: <String, EncodeResult>{
          for (final check.EncodeTestResult result in found.encode)
            result.format.toString(): EncodeResult(
              ok: result.ok,
              realtimeFactor: result.ok ? result.realtimeFactor : null,
            ),
        },
        decode: <String, double>{
          for (final check.DecodeTestResult result in found.decode)
            if (result.ok) _nameOf(result.sample): result.realtimeFactor,
        },
      );
    } on CancelledException {
      logger.info(_tag, 'The media tests were cancelled');
      return DeviceMediaCheckResult(
        encode: const <String, EncodeResult>{},
        decode: const <String, double>{},
      );
    } finally {
      await _deleteSamples(samples);
    }
  }

  /// The samples copied into scratch, in order; one that cannot be loaded
  /// is logged and left out.
  Future<List<String>> _copySamples() async {
    final List<String> copied = <String>[];
    for (final String assetKey in _samples) {
      final String path = '$_folder/${assetKey.split('/').last}';
      try {
        final ByteData data = await loadAsset(assetKey);
        final File file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
        copied.add(path);
      } on Object catch (error, stackTrace) {
        logger.warning(
          _tag,
          'Could not copy the decode sample $assetKey',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return copied;
  }

  Future<void> _deleteSamples(List<String> samples) async {
    for (final String sample in samples) {
      try {
        await File(sample).delete();
      } on FileSystemException {
        // Already gone.
      }
    }
  }

  String get _folder => '${paths.scratchDir}/calibration';

  /// `iphone-4k60-h264` for `.../iphone-4k60-h264.mp4`.
  static String _nameOf(String path) {
    final String file = path.split('/').last;
    final int dot = file.lastIndexOf('.');
    return dot <= 0 ? file : file.substring(0, dot);
  }
}

final class _Run implements DeviceMediaCheckRun {
  const _Run({required this.result, required this.token});

  @override
  final Future<DeviceMediaCheckResult> result;

  final CancelToken token;

  @override
  Future<void> cancel() async => token.cancel();
}
