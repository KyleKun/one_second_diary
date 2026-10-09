import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/policy/encoder_policy.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';

/// Whether a job that writes a lot may start ([StorageBudget.check]).
sealed class StorageVerdict extends Equatable {
  const StorageVerdict();
}

/// Enough is free, or the free space is not known (a job is never refused
/// on a guess).
final class StorageOk extends StorageVerdict {
  const StorageOk();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The phone lacks [shortfallBytes]: the job is refused before any work,
/// and the message says how much to free (`Strings.storageShort`).
final class StorageShort extends StorageVerdict {
  const StorageShort({required this.shortfallBytes});

  final int shortfallBytes;

  @override
  List<Object?> get props => <Object?>[shortfallBytes];
}

/// What a clip save needs free, for the camera and editor lane's
/// `ClipSaver` to ask [StorageBudget.check] before rendering
///: the source copy, when one is made, and twice the
/// estimated clip size (the render in scratch and its copy into the
/// gallery on Android).
final class SaveSpaceEstimate extends Equatable {
  const SaveSpaceEstimate({
    required this.format,
    required this.durationMs,
    this.sourceCopyBytes = 0,
  });

  final ClipFormat format;
  final int durationMs;

  /// The bytes of a source the save copies first (a kept original); 0
  /// when the source is only read.
  final int sourceCopyBytes;

  int get neededBytes => StorageBudget.saveBytes(
    format: format,
    durationMs: durationMs,
    sourceCopyBytes: sourceCopyBytes,
  );

  @override
  List<Object?> get props => <Object?>[format, durationMs, sourceCopyBytes];
}

/// One policy for the free space every heavy job checks first: the bytes a save, a movie, a conversion and
/// the phone check need, and the verdict against what the phone has free.
///
/// | job | needed |
/// |---|---|
/// | save | source copy (if any) + 2 × estimated clip size |
/// | movie | Σ normalised copies at the target bitrate + the movie twice |
/// | convert | Σ duration × target bitrate × 1.1 + scratch |
/// | phone check | a few MB |
///
/// A floor of free space is always kept ([floorBytes], 200 MB), so a job
/// never leaves the phone with nothing. The free space comes from
/// `FreeSpaceGateway`; null means unknown, and the job goes ahead (other
/// apps write too; a phone that fills up is `StorageSpace.isOutOfSpace`).
abstract final class StorageBudget {
  /// The free space every job leaves untouched.
  static const int floorBytes = 200 * 1000 * 1000;

  /// What the phone check writes: its synthetic encodes, a few MB.
  static const int phoneCheckBytes = 8 * 1000 * 1000;

  /// Above a clip's own bytes, the share the converter's scratch takes
  /// (the render before it is published).
  static const double convertMargin = 1.1;

  /// Whether a job needing [needed] bytes may start with [free] bytes free
  /// (null: not known, so [StorageOk]). Short by what is missing beyond
  /// [floorBytes].
  static StorageVerdict check({required int needed, required int? free}) {
    if (free == null) return const StorageOk();
    final int shortfall = needed + floorBytes - free;
    return shortfall > 0
        ? StorageShort(shortfallBytes: shortfall)
        : const StorageOk();
  }

  /// The bytes a clip of [durationMs] in [format] takes on disk, from the
  /// format's video bitrate (`EncoderPolicy`) plus its audio (256 kb/s).
  static int clipBytes({required ClipFormat format, required int durationMs}) {
    const int audioBitsPerSecond = 256 * 1000;
    final int bitsPerSecond =
        EncoderPolicy.bitrateFor(format) + audioBitsPerSecond;
    return (bitsPerSecond / 8 * durationMs / 1000).ceil();
  }

  /// A save: the source copy, when one is made, and twice the estimated
  /// clip size (scratch, then the gallery copy on Android).
  static int saveBytes({
    required ClipFormat format,
    required int durationMs,
    int sourceCopyBytes = 0,
  }) => sourceCopyBytes + 2 * clipBytes(format: format, durationMs: durationMs);

  /// A movie of clips weighing [clipBytes] on disk: the normalised copies
  /// the engine makes first ([normalisedBytes], Σ duration × the target
  /// bitrate of the clips that need one) and the movie twice (joined in
  /// scratch, then copied into the gallery on Android).
  static int movieBytes({required int clipBytes, int normalisedBytes = 0}) =>
      normalisedBytes + 2 * clipBytes;

  /// A conversion of clips totalling [totalDurationMs] into [format]: Σ
  /// duration × the target bitrate, times [convertMargin] for the scratch
  /// render of the clip in flight.
  static int convertBytes({
    required ClipFormat format,
    required int totalDurationMs,
  }) => (clipBytes(format: format, durationMs: totalDurationMs) * convertMargin)
      .ceil();

  /// The cap of the normalised-copy cache (`NormalizedCopyCache`): 10 % of
  /// the free space, never under [cacheCapMinBytes] nor over
  /// [cacheCapMaxBytes]; the minimum when the free space is not known.
  /// Re-evaluated at each trim.
  static int normalizedCacheCap(int? freeBytes) {
    if (freeBytes == null) return cacheCapMinBytes;
    return math.min(
      cacheCapMaxBytes,
      math.max(cacheCapMinBytes, freeBytes ~/ 10),
    );
  }

  /// 512 MiB.
  static const int cacheCapMinBytes = 512 * 1024 * 1024;

  /// 8 GiB.
  static const int cacheCapMaxBytes = 8 * 1024 * 1024 * 1024;
}
