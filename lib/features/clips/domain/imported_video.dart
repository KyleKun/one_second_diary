import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// A date-named video in the diary folder that the app did not make: an
/// indexed clip whose cached schema is `other` ([clip] set), or a date-named
/// file with another extension beside the clips (`ClipScan.foreignFiles`,
/// [clip] null). What the processing sheet lists and the `ImportProcessor`
/// works through.
final class ImportedVideo extends Equatable {
  const ImportedVideo({
    required this.profile,
    required this.relPath,
    required this.day,
    this.clip,
    this.durationMs,
    this.colorTransfer,
  });

  final ProfileKey profile;

  /// The file, relative to `AppPaths.videos`.
  final String relPath;

  /// The day its name says.
  final LocalDay day;

  /// The indexed clip it is, or null for a file the index never takes.
  final ClipRef? clip;

  /// Its length, from the metadata cache or a probe; null until known.
  final int? durationMs;

  /// Its video's `color_transfer`, from the same cache entry or probe
  /// (`arib-std-b67`, `smpte2084`: an HDR video, which processing converts
  /// into the profile's range); null for SDR or until known.
  final String? colorTransfer;

  bool get isIndexed => clip != null;

  /// This video with its probed [durationMs] and [colorTransfer].
  ImportedVideo withDuration(int durationMs, {String? colorTransfer}) =>
      ImportedVideo(
        profile: profile,
        relPath: relPath,
        day: day,
        clip: clip,
        durationMs: durationMs,
        colorTransfer: colorTransfer ?? this.colorTransfer,
      );

  @override
  List<Object?> get props => <Object?>[
    profile,
    relPath,
    day,
    clip,
    durationMs,
    colorTransfer,
  ];
}

/// How the processing sheet's choices shape each clip, both remembered in
/// preferences (`PrefKeys.importKeepWhole`, `PrefKeys.importDateStamp`).
final class ImportChoices extends Equatable {
  const ImportChoices({
    required this.keepWhole,
    required this.dateStamp,
    required this.quickCutMs,
  });

  /// The clip limit: a longer file keeps its first [maxWholeMs].
  static const int maxWholeMs = 60000;

  /// Keep the whole video (up to [maxWholeMs]) instead of the first
  /// [quickCutMs].
  final bool keepWhole;

  /// Burn the date stamp of the file's day.
  final bool dateStamp;

  /// The remembered quick cut (`PrefKeys.lastQuickCutMs`).
  final int quickCutMs;

  /// The end of the trim for a source of [sourceMs]: never past the
  /// source, never past the clip limit.
  int trimEndMs(int sourceMs) {
    final int wanted = keepWhole ? maxWholeMs : quickCutMs;
    return wanted < sourceMs ? wanted : sourceMs;
  }

  ImportChoices copyWith({bool? keepWhole, bool? dateStamp}) => ImportChoices(
    keepWhole: keepWhole ?? this.keepWhole,
    dateStamp: dateStamp ?? this.dateStamp,
    quickCutMs: quickCutMs,
  );

  @override
  List<Object?> get props => <Object?>[keepWhole, dateStamp, quickCutMs];
}

/// Why one video could not be processed.
enum ImportSkipReason {
  /// The move of the original beside the diary was refused or failed (on
  /// Android, the user declined); the original stays where it was.
  moveRefused,

  /// The engine could not read or render it.
  renderFailed,

  /// The gallery refused the processed clip; the original is back.
  publishFailed,

  /// The file is gone (deleted or moved meanwhile).
  missing,
}

/// What a run of the `ImportProcessor` did.
final class ImportReport extends Equatable {
  const ImportReport({
    required this.processed,
    required this.skipped,
    required this.cancelled,
  });

  static const ImportReport nothing = ImportReport(
    processed: <ClipRef>[],
    skipped: <ImportedVideo, ImportSkipReason>{},
    cancelled: false,
  );

  /// The clips made, in order.
  final List<ClipRef> processed;

  /// The videos left as they were, with why.
  final Map<ImportedVideo, ImportSkipReason> skipped;

  /// Whether the user stopped the run; what was done is kept.
  final bool cancelled;

  /// Whether the whole batch was skipped because the move was refused
  /// ("Allow One Second Diary to move the original videos, or process them
  /// one by one").
  bool get moveRefused =>
      skipped.isNotEmpty &&
      skipped.values.every(
        (ImportSkipReason reason) => reason == ImportSkipReason.moveRefused,
      );

  @override
  List<Object?> get props => <Object?>[processed, skipped, cancelled];
}

/// What the `ImportProcessor` reports as it works.
sealed class ImportEvent extends Equatable {
  const ImportEvent();
}

/// Work on video [index] of [total] (0-based), [fraction] of its render
/// done.
final class ImportProgress extends ImportEvent {
  const ImportProgress({
    required this.index,
    required this.total,
    required this.fraction,
  });

  final int index;
  final int total;
  final double fraction;

  @override
  List<Object?> get props => <Object?>[index, total, fraction];
}

/// [video] became [clip].
final class ImportVideoDone extends ImportEvent {
  const ImportVideoDone({required this.video, required this.clip});

  final ImportedVideo video;
  final ClipRef clip;

  @override
  List<Object?> get props => <Object?>[video, clip];
}

/// [video] was left as it was.
final class ImportVideoSkipped extends ImportEvent {
  const ImportVideoSkipped({required this.video, required this.reason});

  final ImportedVideo video;
  final ImportSkipReason reason;

  @override
  List<Object?> get props => <Object?>[video, reason];
}

/// The run ended, by the end of the list or a cancel.
final class ImportFinished extends ImportEvent {
  const ImportFinished(this.report);

  final ImportReport report;

  @override
  List<Object?> get props => <Object?>[report];
}
