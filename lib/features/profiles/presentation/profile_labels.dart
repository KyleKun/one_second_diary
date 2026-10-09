import 'package:intl/intl.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/quality_recommender.dart';

/// The text that describes a profile in lists, and its format in the
/// quality picker.
abstract final class ProfileLabels {
  static String orientation(VideoOrientation orientation) =>
      switch (orientation) {
        VideoOrientation.landscape => Strings.landscape,
        VideoOrientation.portrait => Strings.portrait,
      };

  /// "Landscape · 914 videos" (the count in [languageCode]'s digits and
  /// grouping), "Portrait · No videos yet", or just the orientation while
  /// the profile's diary has not been read ([count] null).
  static String row(
    Profile profile, {
    required int? count,
    required String languageCode,
  }) {
    final String shape = orientation(profile.orientation);
    return switch (count) {
      null => shape,
      0 => Strings.profileRowSubtitleEmpty(orientation: shape),
      final int count => Strings.profileRowSubtitle(
        count,
        orientation: shape,
        format: LocaleFormats.forLocale(languageCode).numbers,
      ),
    };
  }

  /// "720p", "1080p", "1440p", "4K".
  static String tier(ResolutionTier tier) => switch (tier) {
    ResolutionTier.p720 => Strings.qualityTier720,
    ResolutionTier.p1080 => Strings.qualityTier1080,
    ResolutionTier.p1440 => Strings.qualityTier1440,
    ResolutionTier.p2160 => Strings.qualityTier2160,
  };

  static String codec(VideoCodec codec) => switch (codec) {
    VideoCodec.h264 => Strings.qualityCodecH264,
    VideoCodec.hevc => Strings.qualityCodecHevc,
  };

  /// "30 fps".
  static String fps(FrameRate fps) => Strings.qualityFps(fps: fps.token);

  static String audio(AudioChannels channels) => switch (channels) {
    AudioChannels.mono => Strings.qualityMono,
    AudioChannels.stereo => Strings.qualityStereo,
  };

  static String range(DynamicRange range) => switch (range) {
    DynamicRange.sdr => Strings.qualitySdr,
    DynamicRange.hlg => Strings.qualityHlg,
  };

  /// "4K 60 fps · HEVC · Stereo"; "… · HDR (HLG)" for an HLG format.
  static String format(ClipFormat format) {
    final String summary = Strings.qualityFormatSummary(
      tier: tier(format.tier),
      fps: fps(format.fps),
      codec: codec(format.codec),
      audio: audio(format.channels),
    );
    return format.isHdr
        ? Strings.qualityFormatSummaryHdr(
            summary: summary,
            range: range(format.range),
          )
        : summary;
  }

  /// The preset's name, or the format summary for an Advanced choice.
  static String formatOrPreset(ClipFormat format) {
    final ClipFormatPreset? preset = ClipFormatPreset.of(format);
    return preset == null ? ProfileLabels.format(format) : name(preset);
  }

  static String name(ClipFormatPreset preset) => switch (preset) {
    ClipFormatPreset.standard => Strings.qualityPresetStandard,
    ClipFormatPreset.smallerFiles => Strings.qualityPresetSmallerFiles,
    ClipFormatPreset.high => Strings.qualityPresetHigh,
    ClipFormatPreset.ultra => Strings.qualityPresetUltra,
  };

  static String pitch(ClipFormatPreset preset) => switch (preset) {
    ClipFormatPreset.standard => Strings.qualityPresetStandardPitch,
    ClipFormatPreset.smallerFiles => Strings.qualityPresetSmallerFilesPitch,
    ClipFormatPreset.high => Strings.qualityPresetHighPitch,
    ClipFormatPreset.ultra => Strings.qualityPresetUltraPitch,
  };

  /// The per-choice line of the picker: "Saving a 3 s clip takes about
  /// 4 s", "Slow on this phone", "Not supported on this phone", or null
  /// when the phone was not checked.
  static String? availability(
    FormatAvailability availability, {
    NumberFormat? format,
  }) => switch (availability) {
    FormatAvailable(:final bool slow, :final int saveSeconds) =>
      slow
          ? Strings.qualitySlow
          : Strings.qualitySaveTime(
              seconds: format?.format(saveSeconds) ?? '$saveSeconds',
            ),
    FormatUnsupported() => Strings.qualityNotSupported,
    FormatNotChecked() => null,
  };

  /// "480 GB" / "512 MB": a byte count for the recommendation line and the
  /// estimate card.
  static String bytes(int bytes, {NumberFormat? format}) {
    const int mega = 1000 * 1000;
    const int giga = mega * 1000;
    if (bytes >= giga) {
      final double gigabytes = bytes / giga;
      final String size = gigabytes >= 10
          ? (format?.format(gigabytes.round()) ?? '${gigabytes.round()}')
          : (format?.format(double.parse(gigabytes.toStringAsFixed(1))) ??
                gigabytes.toStringAsFixed(1));
      return Strings.movieSizeGigabytes(size: size);
    }
    final int megabytes = (bytes / mega).round();
    return Strings.movieSizeMegabytes(
      size: format?.format(megabytes) ?? '$megabytes',
    );
  }

  /// "Your phone encodes 4K 60 at 2.4× real time and has 480 GB free".
  static String? reason(
    QualityRecommendation recommendation, {
    NumberFormat? format,
  }) {
    final double? factor = recommendation.pickFactor;
    final int? free = recommendation.freeBytes;
    if (!recommendation.checked || factor == null || free == null) return null;
    return Strings.qualityRecommendationReason(
      format: ProfileLabels.format(recommendation.pick),
      factor: factor.toStringAsFixed(1),
      free: bytes(free, format: format),
    );
  }

  /// "about 12 min" / "about 40 s": a duration in whole minutes or
  /// seconds, for the estimate card.
  static String duration(int seconds) => seconds >= 60
      ? Strings.journeyDurationMinutes((seconds / 60).round())
      : Strings.journeyDurationSeconds(seconds);
}
