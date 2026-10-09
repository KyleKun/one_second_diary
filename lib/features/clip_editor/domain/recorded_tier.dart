import 'dart:math' as math;

import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/platform/capture_quality.dart';

/// What the camera achieved, read against the profile's tier: the editor says "Recorded at 1080p" when the recording
/// is below the profile's canvas (the clip is still saved in the profile's format, scaled up).
abstract final class RecordedTier {
  /// The tier [size] fills: the largest whose short side the recording
  /// reaches, or the smallest for a recording under 720p.
  static ResolutionTier of(AchievedSize size) {
    final int shortSide = math.min(size.width, size.height);
    ResolutionTier reached = ResolutionTier.values.first;
    for (final ResolutionTier tier in ResolutionTier.values) {
      if (tier.shortSide <= shortSide) reached = tier;
    }
    return reached;
  }

  /// Whether a recording of [size] is below [format]'s tier, so the editor
  /// notes it.
  static bool isBelow(AchievedSize size, ClipFormat format) =>
      math.min(size.width, size.height) < format.tier.shortSide;

  /// The tier the editor notes for an in-app [recording], or null. It is
  /// read off the [source] file's probed size (`EditClipState.sourceSize`),
  /// never the camera session's achieved size (`EditClipArgs.recordedSize`,
  /// which only says the source is a recording): on Android that size is
  /// the CameraX preview's, capped near the display size whatever the
  /// video use case records, so a 4K take would read as 1080p. Null until
  /// the size is probed, and for a take that reaches [format]'s tier.
  static ResolutionTier? noted({
    required bool recording,
    required AchievedSize? source,
    required ClipFormat format,
  }) {
    if (!recording || source == null || !isBelow(source, format)) return null;
    return of(source);
  }
}
