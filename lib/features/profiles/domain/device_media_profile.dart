import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

/// What one synthetic encode test of the phone check found for a format.
final class EncodeResult extends Equatable {
  const EncodeResult({required this.ok, this.realtimeFactor});

  /// The format could not be encoded at all (or the test did not finish).
  const EncodeResult.failed() : ok = false, realtimeFactor = null;

  /// Whether the encoder produced a playable file.
  final bool ok;

  /// Seconds of video encoded per wall second (2.4 = a 3 s clip in about
  /// 1.25 s); null when the test failed.
  final double? realtimeFactor;

  Map<String, Object?> toJson() => <String, Object?>{
    'ok': ok,
    if (realtimeFactor != null) 'factor': realtimeFactor,
  };

  /// Null for anything that is not an object with a boolean `ok`.
  static EncodeResult? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? ok = json['ok'];
    final Object? factor = json['factor'];
    if (ok is! bool) return null;
    return EncodeResult(
      ok: ok,
      realtimeFactor: factor is num ? factor.toDouble() : null,
    );
  }

  @override
  List<Object?> get props => <Object?>[ok, realtimeFactor];
}

/// What the camera probe of the phone check found: the largest tier the
/// back camera achieves, whether it records 60 fps, and how many channels
/// its microphone gives.
final class CameraCapability extends Equatable {
  const CameraCapability({
    required this.maxTier,
    required this.fps60,
    required this.channels,
  });

  final ResolutionTier maxTier;
  final bool fps60;

  /// 1 or 2.
  final int channels;

  Map<String, Object?> toJson() => <String, Object?>{
    'maxTier': maxTier.token,
    'fps60': fps60,
    'channels': channels,
  };

  static CameraCapability? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? tier = json['maxTier'];
    final Object? fps60 = json['fps60'];
    final Object? channels = json['channels'];
    if (tier is! String || fps60 is! bool || channels is! int) return null;
    for (final ResolutionTier candidate in ResolutionTier.values) {
      if (candidate.token == tier) {
        return CameraCapability(
          maxTier: candidate,
          fps60: fps60,
          channels: channels,
        );
      }
    }
    return null;
  }

  @override
  List<Object?> get props => <Object?>[maxTier, fps60, channels];
}

/// The result of the phone check: what this phone encodes and decodes, what
/// its camera captures and how much space it has, from which
/// `QualityRecommender` picks a format.
///
/// Stored as JSON in the `deviceMediaProfile` preference. Encode results are
/// keyed by the format's canonical string (`ClipFormat.toString`, no
/// orientation), decode results by the bundled sample's name.
final class DeviceMediaProfile extends Equatable {
  DeviceMediaProfile({
    required this.checkedAt,
    required this.appVersion,
    required this.deviceModel,
    Map<String, EncodeResult> encode = const <String, EncodeResult>{},
    Map<String, double> decode = const <String, double>{},
    this.camera,
    this.freeBytes,
  }) : encode = Map<String, EncodeResult>.unmodifiable(encode),
       decode = Map<String, double>.unmodifiable(decode);

  /// The schema of the stored JSON; a different one reads as "never ran".
  static const int version = 1;

  final DateTime checkedAt;

  /// The app version that ran the check.
  final String appVersion;

  /// The phone that ran the check (`iPhone15,2`, `Google Pixel 8`).
  final String deviceModel;

  /// Per candidate format (canonical string).
  final Map<String, EncodeResult> encode;

  /// Per bundled sample: the real-time factor of its decode.
  final Map<String, double> decode;

  /// Null when the camera test could not run (no camera permission yet).
  final CameraCapability? camera;

  /// Free bytes on the diary's storage when the check ran; null when the
  /// phone could not tell.
  final int? freeBytes;

  /// The encode result of [format] (any orientation), or null when that
  /// format was not tested.
  EncodeResult? encodeOf(ClipFormat format) => encode[format.toString()];

  /// Whether the check was made by another app version or on another
  /// phone (a backup restored elsewhere): the picker then says "Check
  /// again" and the recommendation falls back to Standard.
  bool isStaleFor({required String appVersion, required String deviceModel}) =>
      this.appVersion != appVersion || this.deviceModel != deviceModel;

  /// Whether the check ran on another phone: the one case that re-runs it
  /// quietly.
  bool isFromAnotherPhone(String deviceModel) =>
      this.deviceModel != deviceModel;

  /// The formats that were tested, as landscape formats.
  Iterable<ClipFormat> get testedFormats => <ClipFormat>[
    for (final String key in encode.keys)
      if (ClipFormat.parse(key, VideoOrientation.landscape)
          case final ClipFormat format)
        format,
  ];

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'checkedAt': checkedAt.toIso8601String(),
    'appVersion': appVersion,
    'deviceModel': deviceModel,
    'encode': <String, Object?>{
      for (final MapEntry<String, EncodeResult> entry in encode.entries)
        entry.key: entry.value.toJson(),
    },
    'decode': Map<String, double>.of(decode),
    if (camera != null) 'camera': camera!.toJson(),
    if (freeBytes != null) 'freeBytes': freeBytes,
  };

  /// Null for anything that is not a complete profile of [version]: a
  /// malformed value reads as "the check never ran".
  static DeviceMediaProfile? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    if (json['version'] != version) return null;
    final Object? checkedAt = json['checkedAt'];
    final Object? appVersion = json['appVersion'];
    final Object? deviceModel = json['deviceModel'];
    if (checkedAt is! String ||
        appVersion is! String ||
        deviceModel is! String) {
      return null;
    }
    final DateTime? when = DateTime.tryParse(checkedAt);
    if (when == null) return null;
    final Object? encode = json['encode'];
    final Object? decode = json['decode'];
    final Object? freeBytes = json['freeBytes'];
    return DeviceMediaProfile(
      checkedAt: when,
      appVersion: appVersion,
      deviceModel: deviceModel,
      encode: <String, EncodeResult>{
        if (encode is Map<String, dynamic>)
          for (final MapEntry<String, dynamic> entry in encode.entries)
            if (EncodeResult.fromJson(entry.value)
                case final EncodeResult result)
              entry.key: result,
      },
      decode: <String, double>{
        if (decode is Map<String, dynamic>)
          for (final MapEntry<String, dynamic> entry in decode.entries)
            if (entry.value case final num factor) entry.key: factor.toDouble(),
      },
      camera: CameraCapability.fromJson(json['camera']),
      freeBytes: freeBytes is int ? freeBytes : null,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    checkedAt,
    appVersion,
    deviceModel,
    encode,
    decode,
    camera,
    freeBytes,
  ];
}
