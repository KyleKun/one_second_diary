import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// How fast this phone encodes [format], as the phone check measured it
/// (`DeviceMediaProfile`, profiles lane): the real-time factor, 1.0 when a
/// second of video takes a second to save. Unknown is taken as 1.0.
typedef EncodeSpeedOf = double Function(ClipFormat format);

/// A conversion to run: every clip of [source] into [target], which the
/// profiles sheet created with [format] before asking.
final class ConversionJob extends Equatable {
  const ConversionJob({
    required this.source,
    required this.target,
    required this.format,
  });

  final ProfileKey source;
  final ProfileKey target;
  final ClipFormat format;

  @override
  List<Object?> get props => <Object?>[source, target, format];
}

/// What the entry sheet shows before converting: the count, the total
/// length, the time on this phone, the space needed and whether there is
/// room (`StorageBudget`); [sameFormat] when the target equals the source
/// format, so the conversion is not offered.
final class ConversionEstimate extends Equatable {
  const ConversionEstimate({
    required this.clipCount,
    required this.totalDurationMs,
    required this.estimatedTime,
    required this.neededBytes,
    required this.verdict,
    required this.sameFormat,
    this.sourceCopyBytes = 0,
  });

  final int clipCount;

  /// Σ the clips' lengths; clips the cache has not read count as the
  /// average known clip.
  final int totalDurationMs;

  /// About how long the whole conversion takes on this phone.
  final Duration estimatedTime;

  final int neededBytes;

  final StorageVerdict verdict;

  final bool sameFormat;

  /// The bytes of the kept originals the new profile gets copies of, counted
  /// in [neededBytes]; 0 when "Keep original recordings" is off or no clip has
  /// one.
  final int sourceCopyBytes;

  /// Whether the conversion may start: a format that differs, at least one
  /// clip, and room for it.
  bool get canStart => !sameFormat && clipCount > 0 && verdict is StorageOk;

  @override
  List<Object?> get props => <Object?>[
    clipCount,
    totalDurationMs,
    estimatedTime,
    neededBytes,
    verdict,
    sameFormat,
    sourceCopyBytes,
  ];
}

/// Why one clip was not converted.
enum ConversionSkipReason {
  /// The engine could not read or render it.
  renderFailed,

  /// The gallery refused the converted clip.
  publishFailed,

  /// The source file is gone.
  missing,
}

/// What a run did (so far: a cancel keeps it).
final class ConversionReport extends Equatable {
  const ConversionReport({
    required this.done,
    required this.total,
    required this.skipped,
    required this.cancelled,
    this.sourcesCopied = 0,
    this.sourcesSkipped = 0,
  });

  /// Converted in this and earlier runs (the manifest).
  final int done;

  final int total;

  final Map<ClipRef, ConversionSkipReason> skipped;

  final bool cancelled;

  /// The kept originals the new profile got copies of, and those it did not
  /// (the switch off, or no room: the sheet says the new profile has no
  /// sources).
  final int sourcesCopied;
  final int sourcesSkipped;

  bool get complete => !cancelled && done + skipped.length >= total;

  @override
  List<Object?> get props => <Object?>[
    done,
    total,
    skipped,
    cancelled,
    sourcesCopied,
    sourcesSkipped,
  ];
}

/// What the converter reports as it works.
sealed class ConversionEvent extends Equatable {
  const ConversionEvent();
}

/// Clip [done] of [total] in flight ([fraction] of it rendered), with
/// about [remaining] left for the rest: "n of N · about 12 min left".
final class ConversionProgress extends ConversionEvent {
  const ConversionProgress({
    required this.done,
    required this.total,
    required this.fraction,
    required this.remaining,
  });

  final int done;
  final int total;
  final double fraction;
  final Duration remaining;

  @override
  List<Object?> get props => <Object?>[done, total, fraction, remaining];
}

/// [source] became [target] in the new profile.
final class ConversionClipDone extends ConversionEvent {
  const ConversionClipDone({required this.source, required this.target});

  final ClipRef source;
  final ClipRef target;

  @override
  List<Object?> get props => <Object?>[source, target];
}

/// [source] was left out.
final class ConversionClipSkipped extends ConversionEvent {
  const ConversionClipSkipped({required this.source, required this.reason});

  final ClipRef source;
  final ConversionSkipReason reason;

  @override
  List<Object?> get props => <Object?>[source, reason];
}

/// The run ended: the list is through, or the user cancelled.
final class ConversionFinished extends ConversionEvent {
  const ConversionFinished(this.report);

  final ConversionReport report;

  @override
  List<Object?> get props => <Object?>[report];
}

/// What the profiles lane's entry sheet ("Convert into a new profile…",
/// the post-update sheet) talks to: the estimate before, the run after.
/// Implemented by `ProfileConverter` (`features/clips/data`).
abstract interface class ProfileConversionStarter {
  /// The estimate for every clip of [source] into [format].
  Future<ConversionEstimate> estimateConversion({
    required ProfileKey source,
    required ClipFormat format,
  });

  /// Converts [job]'s clips in date order, one at a time, resuming where a
  /// killed app stopped. Cancelling [cancelToken] ends after the clip in
  /// flight; what was converted is kept.
  Stream<ConversionEvent> convertProfile(
    ConversionJob job, {
    CancelToken? cancelToken,
  });
}
