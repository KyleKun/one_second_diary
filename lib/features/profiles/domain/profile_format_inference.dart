import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';

/// What a profile found on the phone after a reinstall was made for, read
/// off its newest clips' probed facts instead of assuming landscape and legacy.
///
/// Pure: the newest clip with a size decides the orientation; the newest clip
/// with facts decides the format. The app's own clips (`v1.5` or `v2` marker)
/// are read before a foreign one (`ClipSchema.other`, an imported video),
/// which must not decide a write-once format. A `v1.5` clip is legacy whatever
/// else it says. Anything the facts can't tell reads as the legacy value.
abstract final class ProfileFormatInference {
  /// The colour transfers that mean HLG (HDR).
  static const Set<String> hlgTransfers = <String>{'arib-std-b67'};

  /// Frame rates from this up read as 60 fps.
  static const double sixtyFrom = 45;

  /// The canvas and format of a profile whose newest clips have [facts]
  /// (newest first); landscape and legacy when nothing tells.
  static ({VideoOrientation orientation, ClipFormat format}) infer(
    List<ClipMeta> facts,
  ) {
    final VideoOrientation orientation = inferOrientation(facts);
    return (orientation: orientation, format: inferFormat(facts, orientation));
  }

  /// Portrait when the newest clip with a size is taller than wide.
  static VideoOrientation inferOrientation(List<ClipMeta> facts) {
    for (final ClipMeta meta in _ownFirst(facts)) {
      final int? width = meta.width;
      final int? height = meta.height;
      if (width == null || height == null || width <= 0 || height <= 0) {
        continue;
      }
      return height > width
          ? VideoOrientation.portrait
          : VideoOrientation.landscape;
    }
    return VideoOrientation.landscape;
  }

  /// The format of the newest clip with a schema, size or codec, on
  /// [orientation].
  static ClipFormat inferFormat(
    List<ClipMeta> facts,
    VideoOrientation orientation,
  ) {
    for (final ClipMeta meta in _ownFirst(facts)) {
      if (meta.schema == ClipSchema.v15) return ClipFormat.legacy(orientation);
      final bool tells =
          meta.schema != null ||
          meta.codec != null ||
          (meta.width != null && meta.height != null);
      if (!tells) continue;
      final VideoCodec codec = _codecOf(meta.codec) ?? VideoCodec.h264;
      return ClipFormat(
        tier: _tierOf(meta) ?? ResolutionTier.p1080,
        orientation: orientation,
        codec: codec,
        fps: (meta.fps ?? 0) >= sixtyFrom ? FrameRate.f60 : FrameRate.f30,
        channels: (meta.channels ?? 1) >= 2
            ? AudioChannels.stereo
            : AudioChannels.mono,
        // HLG is HEVC only (`ClipFormat.isValid`): an H.264 clip tagged
        // HLG (8-bit, which the app never writes) reads as SDR.
        range:
            codec == VideoCodec.hevc &&
                hlgTransfers.contains(meta.colorTransfer)
            ? DynamicRange.hlg
            : DynamicRange.sdr,
      );
    }
    return ClipFormat.legacy(orientation);
  }

  /// [facts] with the app's own clips first (newest first within each
  /// group) and the foreign ones after.
  static List<ClipMeta> _ownFirst(List<ClipMeta> facts) => <ClipMeta>[
    for (final ClipMeta meta in facts)
      if (meta.schema != ClipSchema.other) meta,
    for (final ClipMeta meta in facts)
      if (meta.schema == ClipSchema.other) meta,
  ];

  /// The tier whose short side the clip has exactly; null otherwise (a
  /// clip of another size is not one the app made at that tier).
  static ResolutionTier? _tierOf(ClipMeta meta) {
    final int? width = meta.width;
    final int? height = meta.height;
    if (width == null || height == null) return null;
    final int shortSide = width < height ? width : height;
    for (final ResolutionTier tier in ResolutionTier.values) {
      if (tier.shortSide == shortSide) return tier;
    }
    return null;
  }

  static VideoCodec? _codecOf(String? codec) {
    for (final VideoCodec candidate in VideoCodec.values) {
      if (candidate.token == codec) return candidate;
    }
    return null;
  }
}
