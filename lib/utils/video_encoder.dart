import 'dart:convert';

import 'ffmpeg_api_wrapper.dart';
import 'platform_utils.dart';
import 'utils.dart';

/// Picks the H.264 encoder the app renders with, and the arguments that go
/// with it.
///
/// The app used to hardcode `libx264`, which only exists in the GPL flavours of
/// ffmpeg-kit. A GPL binary cannot be distributed on the App Store, so on iOS
/// the encoder has to be VideoToolbox, Apple's hardware encoder. VideoToolbox
/// has no CRF mode, so the same quality target is expressed as a bitrate.
///
/// The encoder is probed once at startup rather than hardcoded per platform so
/// that the project keeps working with either ffmpeg-kit flavour. With the GPL
/// package Android still selects `libx264` and produces output identical to
/// previous releases; with the LGPL package it falls back to MediaCodec.
class VideoEncoder {
  VideoEncoder._();

  static const String libx264 = 'libx264';
  static const String videoToolbox = 'h264_videotoolbox';
  static const String mediaCodec = 'h264_mediacodec';

  /// Roughly matches what `-crf 20 -preset slow` produces for 1080p30 camera
  /// footage, for the hardware encoders that only accept a bitrate.
  static const int targetBitrateKbps = 12000;

  static String? _selected;

  /// Encoder currently in use. Falls back to a sensible per platform default
  /// when [init] has not run or the probe failed.
  static String get name => _selected ?? defaultFor(isIOS: PlatformUtils.isIOS);

  /// ffmpeg arguments selecting the encoder and its quality target.
  static String get arguments => argumentsFor(name);

  /// Probes the ffmpeg build for the encoders it was compiled with.
  /// Never throws: a failed probe just leaves the platform default in place.
  static Future<void> init() async {
    if (_selected != null) return;
    try {
      final session = await executeFFmpeg('-hide_banner -encoders', showInLogs: false);
      final String output = await session.getOutput() ?? '';
      _selected = select(output, isIOS: PlatformUtils.isIOS);
    } catch (e) {
      _selected = defaultFor(isIOS: PlatformUtils.isIOS);
      Utils.logError('[VideoEncoder] - Could not list encoders ($e), using $_selected');
      return;
    }
    Utils.logInfo('[VideoEncoder] - Encoding with $_selected');
  }

  static String defaultFor({required bool isIOS}) => isIOS ? videoToolbox : libx264;

  static String argumentsFor(String encoder) {
    switch (encoder) {
      case videoToolbox:
        // -allow_sw lets the session fall back to the software encoder when
        // every hardware slot is busy, which happens on the simulator and on
        // older devices while the camera is still shutting down.
        return '-c:v $videoToolbox -b:v ${targetBitrateKbps}k -profile:v high -allow_sw 1';
      case mediaCodec:
        return '-c:v $mediaCodec -b:v ${targetBitrateKbps}k';
      case libx264:
      default:
        return '-c:v $libx264 -crf 20 -preset slow';
    }
  }

  /// Picks the best encoder present in [encodersOutput], the raw output of
  /// `ffmpeg -encoders`.
  ///
  /// On iOS VideoToolbox wins even when libx264 is available: it is several
  /// times faster and it is the only one that can ship on the App Store.
  /// On Android libx264 wins so that a GPL build keeps producing exactly what
  /// previous releases produced.
  static String select(String encodersOutput, {required bool isIOS}) {
    final Set<String> available = parseEncoders(encodersOutput);
    final List<String> preferences = isIOS
        ? <String>[videoToolbox, libx264, mediaCodec]
        : <String>[libx264, mediaCodec, videoToolbox];
    for (final String candidate in preferences) {
      if (available.contains(candidate)) return candidate;
    }
    return defaultFor(isIOS: isIOS);
  }

  /// Parses the encoder names out of `ffmpeg -encoders`, whose rows look like
  /// ` V....D libx264              libx264 H.264 / AVC ...`.
  static Set<String> parseEncoders(String encodersOutput) {
    final RegExp row = RegExp(r'^\s*[VAS][A-Z.]{5}\s+([A-Za-z0-9_]+)\s');
    final Set<String> encoders = <String>{};
    for (final String line in const LineSplitter().convert(encodersOutput)) {
      final Match? match = row.firstMatch(line);
      if (match != null) encoders.add(match.group(1)!);
    }
    return encoders;
  }

  /// Visible for testing.
  static void debugSetEncoder(String? encoder) => _selected = encoder;
}
