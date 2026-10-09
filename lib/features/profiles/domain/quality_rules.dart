import 'package:one_second_diary/core/media/types/clip_format.dart';

/// Every threshold of the format recommendation, in one place.
abstract final class QualityRules {
  /// Rule 2: offered as is from this encode factor (a 3 s clip saves in
  /// about 3 s plus overhead).
  static const double offeredFactor = 1.0;

  /// Rule 2: between this and [offeredFactor] a format is offered with
  /// "slow on this phone"; below it, hidden.
  static const double slowFactor = 0.5;

  /// Rule 3: a year of clips plus one year movie must fit in this share of
  /// the free space.
  static const double freeSpaceShare = 0.10;

  /// Rule 3: a year of 2 s clips, counted twice (the clips and one movie).
  static const int clipsPerYear = 365;
  static const int clipSeconds = 2;
  static const int yearMultiplier = 2;

  /// Rule 1: without a camera probe (no permission yet) nothing above this
  /// tier is recommended, and 60 fps is not.
  static const ResolutionTier unknownCameraTier = ResolutionTier.p1080;

  /// The bundled decode samples, by the name the phone check stores their
  /// decode under (the asset's file name without extension): a phone 4K60
  /// H.264 recording and a 4K30 HEVC 10-bit HLG one. HLG is available only when
  /// this phone decoded [hlgDecodeSample].
  static const String h264DecodeSample = '4k60-h264';
  static const String hlgDecodeSample = '4k30-hevc-hlg';

  /// The per-choice line "Saving a 3 s clip takes about N s": the clip
  /// length shown and the overhead added to the encode time.
  static const int shownClipSeconds = 3;
  static const double saveOverheadSeconds = 1;

  /// Rule 3: bytes a year of clips of [format] takes, with its movie.
  static int yearBytes(ClipFormat format, {required int bitrate}) =>
      clipsPerYear * clipSeconds * (bitrate ~/ 8) * yearMultiplier;

  /// Rule 3: whether [format], at [bitrate] bits per second, fits a year
  /// in [freeBytes]; an unknown free space ([freeBytes] null) never
  /// demotes.
  static bool fitsFreeSpace(
    ClipFormat format, {
    required int bitrate,
    required int? freeBytes,
  }) =>
      freeBytes == null ||
      yearBytes(format, bitrate: bitrate) <= freeBytes * freeSpaceShare;

  /// The seconds the picker says a [shownClipSeconds] clip takes to save
  /// at [realtimeFactor], never under 1.
  static int saveSeconds(double realtimeFactor) {
    if (realtimeFactor <= 0) return shownClipSeconds * 10;
    final double seconds =
        shownClipSeconds / realtimeFactor + saveOverheadSeconds;
    return seconds.ceil().clamp(1, 1 << 30);
  }
}
