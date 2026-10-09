import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/policy/encoder_policy.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';
import 'package:one_second_diary/features/profiles/domain/quality_rules.dart';

/// What the phone check says about one format in the quality picker.
sealed class FormatAvailability extends Equatable {
  const FormatAvailability();
}

/// The phone encodes it at [realtimeFactor]; [slow] below
/// [QualityRules.offeredFactor]. [estimated] when the factor was not
/// measured for this exact format but read off a harder tested one with
/// the same codec.
final class FormatAvailable extends FormatAvailability {
  const FormatAvailable({required this.realtimeFactor, this.estimated = false});

  final double realtimeFactor;
  final bool estimated;

  bool get slow => realtimeFactor < QualityRules.offeredFactor;

  /// "Saving a 3 s clip takes about N s".
  int get saveSeconds => QualityRules.saveSeconds(realtimeFactor);

  @override
  List<Object?> get props => <Object?>[realtimeFactor, estimated];
}

/// The encode test failed, or ran under [QualityRules.slowFactor]: hidden
/// in the picker, "Not supported on this phone" when shown.
final class FormatUnsupported extends FormatAvailability {
  const FormatUnsupported();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The check never ran (or is stale), or it tested nothing that tells.
final class FormatNotChecked extends FormatAvailability {
  const FormatNotChecked();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The phone check's advice: the [pick], why, and what every format the
/// picker may offer looks like in it.
final class QualityRecommendation extends Equatable {
  QualityRecommendation({
    required this.pick,
    required this.checked,
    required Map<ClipFormat, FormatAvailability> choices,
    this.freeBytes,
  }) : choices = Map<ClipFormat, FormatAvailability>.unmodifiable(choices);

  /// The recommended format on the asked orientation; Standard without a
  /// usable check.
  final ClipFormat pick;

  /// Whether a usable (not stale) phone check fed this.
  final bool checked;

  /// Every format the picker may offer on the asked orientation (every
  /// SDR format, HLG on HEVC), with what the phone can do with it.
  final Map<ClipFormat, FormatAvailability> choices;

  /// The free space the check saw; null when unknown or not checked.
  final int? freeBytes;

  /// What the phone can do with [format]; a format no phone can write
  /// (`ClipFormat.isValid`: H.264 with HLG) is unsupported everywhere.
  FormatAvailability of(ClipFormat format) => format.isValid
      ? choices[format.withOrientation(pick.orientation)] ??
            const FormatNotChecked()
      : const FormatUnsupported();

  /// The encode factor of [pick]; null without a check.
  double? get pickFactor => switch (of(pick)) {
    FormatAvailable(:final double realtimeFactor) => realtimeFactor,
    _ => null,
  };

  /// Whether [format] may be chosen: available (slow or not), or
  /// unchecked (the phone was never checked, so nothing is hidden).
  bool isOffered(ClipFormat format) => of(format) is! FormatUnsupported;

  /// The format the picker shows for [preset]: the preset itself when the
  /// phone can do it, else the best it can at or below its tier and frame
  /// rate (same codec, audio and range: a preset is SDR and stays so),
  /// else null (the preset is hidden). A result that differs from the
  /// preset is "demoted" and the picker says so.
  ClipFormat? presetFormat(ClipFormatPreset preset) {
    final ClipFormat wanted = preset.format(pick.orientation);
    if (isOffered(wanted)) return wanted;
    ClipFormat? best;
    for (final MapEntry<ClipFormat, FormatAvailability> entry
        in choices.entries) {
      final ClipFormat format = entry.key;
      if (entry.value is! FormatAvailable ||
          format.range != wanted.range ||
          format.codec != preset.codec ||
          format.channels != preset.channels ||
          format.tier.index > preset.tier.index ||
          format.fps.index > preset.fps.index) {
        continue;
      }
      if (best == null || _higher(format, best)) best = format;
    }
    return best;
  }

  static bool _higher(ClipFormat a, ClipFormat b) =>
      a.tier.index > b.tier.index ||
      (a.tier == b.tier && a.fps.index > b.fps.index);

  @override
  List<Object?> get props => <Object?>[pick, checked, choices, freeBytes];
}

/// Picks a format from a [DeviceMediaProfile]: pure, every threshold in
/// [QualityRules].
///
/// 1. The tier and frame rate are capped at the camera's (1440p is allowed
///    when the camera does 2160p); without a camera probe, at
///    [QualityRules.unknownCameraTier] and 30 fps.
/// 2. Formats encode at [QualityRules.offeredFactor] or more; between
///    [QualityRules.slowFactor] and that they are offered as slow, below
///    hidden.
/// 3. A year of clips plus one movie fits [QualityRules.freeSpaceShare] of
///    the free space.
/// 4. The highest by (tier, fps) wins, HEVC when available; stereo when the
///    camera recorded two channels or on iOS. Never HDR: in-app recordings
///    are SDR.
///
/// An HLG format is available when its encode test passed (its own, or a
/// harder HLG candidate's) AND the phone decoded the bundled HLG sample
/// ([QualityRules.hlgDecodeSample]); anything less is unsupported.
abstract final class QualityRecommender {
  /// Every format the picker may offer, as candidates on [orientation]:
  /// every SDR format, and HLG on HEVC (`ClipFormat.isValid`).
  static List<ClipFormat> candidates(VideoOrientation orientation) =>
      <ClipFormat>[
        for (final DynamicRange range in DynamicRange.values)
          for (final ResolutionTier tier in ResolutionTier.values)
            for (final VideoCodec codec in VideoCodec.values)
              for (final FrameRate fps in FrameRate.values)
                for (final AudioChannels channels in AudioChannels.values)
                  if (ClipFormat(
                        tier: tier,
                        orientation: orientation,
                        codec: codec,
                        fps: fps,
                        channels: channels,
                        range: range,
                      )
                      case final ClipFormat format when format.isValid)
                    format,
      ];

  /// Whether [profile] decoded the bundled HLG sample
  /// ([QualityRules.hlgDecodeSample]): the phone check keeps only the
  /// decodes that succeeded, so an entry is a pass.
  static bool decodesHlg(DeviceMediaProfile profile) =>
      profile.decode.containsKey(QualityRules.hlgDecodeSample);

  /// The recommendation for [profile] on [orientation]. A null [profile]
  /// (never checked, or stale) recommends Standard and offers everything
  /// unchecked.
  static QualityRecommendation recommend({
    required DeviceMediaProfile? profile,
    required VideoOrientation orientation,
    required bool isIOS,
  }) {
    final ClipFormat standard = ClipFormatPreset.standard.format(orientation);
    if (profile == null) {
      return QualityRecommendation(
        pick: standard,
        checked: false,
        choices: <ClipFormat, FormatAvailability>{
          for (final ClipFormat format in candidates(orientation))
            format: format.isHdr
                ? const FormatUnsupported()
                : const FormatNotChecked(),
        },
      );
    }
    final Map<ClipFormat, FormatAvailability> choices =
        <ClipFormat, FormatAvailability>{
          for (final ClipFormat format in candidates(orientation))
            format: availabilityOf(profile, format),
        };
    final CameraCapability? camera = profile.camera;
    final ResolutionTier maxTier =
        camera?.maxTier ?? QualityRules.unknownCameraTier;
    final FrameRate maxFps = (camera?.fps60 ?? false)
        ? FrameRate.f60
        : FrameRate.f30;
    final AudioChannels channels = isIOS || (camera?.channels ?? 1) >= 2
        ? AudioChannels.stereo
        : AudioChannels.mono;

    ClipFormat? best;
    for (final MapEntry<ClipFormat, FormatAvailability> entry
        in choices.entries) {
      final ClipFormat format = entry.key;
      final FormatAvailability availability = entry.value;
      if (format.channels != channels) continue;
      // Rule 4: never HDR.
      if (format.isHdr) continue;
      // Rule 1.
      if (format.tier.index > maxTier.index ||
          format.fps.index > maxFps.index) {
        continue;
      }
      // Rule 2.
      if (availability is! FormatAvailable || availability.slow) continue;
      // Rule 3.
      if (!QualityRules.fitsFreeSpace(
        format,
        bitrate: EncoderPolicy.bitrateFor(format),
        freeBytes: profile.freeBytes,
      )) {
        continue;
      }
      // Rule 4.
      if (best == null || _beats(format, best)) best = format;
    }
    return QualityRecommendation(
      pick: best ?? standard,
      checked: true,
      choices: choices,
      freeBytes: profile.freeBytes,
    );
  }

  /// Rule 4's order: tier, then fps, then HEVC over H.264.
  static bool _beats(ClipFormat a, ClipFormat b) {
    if (a.tier != b.tier) return a.tier.index > b.tier.index;
    if (a.fps != b.fps) return a.fps.index > b.fps.index;
    return a.codec == VideoCodec.hevc && b.codec != VideoCodec.hevc;
  }

  /// What [profile] says about [format]: its own encode test when it was run;
  /// else, since the check escalates from cheap to dear and stops at the first
  /// failure, read off tested formats with the same codec and range: a harder
  /// one that passed gives an estimated factor scaled by the work ratio, an
  /// easier one that failed means unsupported, nothing that tells means not
  /// checked. An HLG format also needs [decodesHlg], else it is unsupported.
  static FormatAvailability availabilityOf(
    DeviceMediaProfile profile,
    ClipFormat format,
  ) {
    final FormatAvailability encode = _encodeAvailabilityOf(profile, format);
    if (!format.isHdr) return encode;
    return encode is FormatAvailable && decodesHlg(profile)
        ? encode
        : const FormatUnsupported();
  }

  static FormatAvailability _encodeAvailabilityOf(
    DeviceMediaProfile profile,
    ClipFormat format,
  ) {
    final EncodeResult? own = profile.encodeOf(format);
    if (own != null) return _of(own, estimated: false);
    if (format.channels != AudioChannels.mono) {
      final EncodeResult? mono = profile.encodeOf(
        ClipFormat(
          tier: format.tier,
          orientation: format.orientation,
          codec: format.codec,
          fps: format.fps,
          channels: AudioChannels.mono,
          range: format.range,
        ),
      );
      if (mono != null) return _of(mono, estimated: false);
    }
    final int work = _work(format);
    ClipFormat? closestAbove;
    EncodeResult? aboveResult;
    bool easierFailed = false;
    for (final ClipFormat tested in profile.testedFormats) {
      if (tested.codec != format.codec || tested.range != format.range) {
        continue;
      }
      final EncodeResult result = profile.encodeOf(tested)!;
      final int testedWork = _work(tested);
      final bool passed =
          result.ok && (result.realtimeFactor ?? 0) >= QualityRules.slowFactor;
      if (testedWork >= work && passed) {
        if (closestAbove == null || testedWork < _work(closestAbove)) {
          closestAbove = tested;
          aboveResult = result;
        }
      } else if (testedWork <= work && !passed) {
        easierFailed = true;
      }
    }
    if (closestAbove != null && aboveResult != null) {
      final double factor =
          aboveResult.realtimeFactor! * _work(closestAbove) / work;
      return FormatAvailable(realtimeFactor: factor, estimated: true);
    }
    if (easierFailed) return const FormatUnsupported();
    return const FormatNotChecked();
  }

  static FormatAvailability _of(
    EncodeResult result, {
    required bool estimated,
  }) {
    final double? factor = result.realtimeFactor;
    if (!result.ok || factor == null || factor < QualityRules.slowFactor) {
      return const FormatUnsupported();
    }
    return FormatAvailable(realtimeFactor: factor, estimated: estimated);
  }

  /// Pixels per second: how hard a format is to encode.
  static int _work(ClipFormat format) =>
      format.shortSide * format.longSide * format.fpsValue;
}
