import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_render_plan.dart';
import 'package:one_second_diary/features/clip_editor/domain/edit_clip_draft.dart';
import 'package:one_second_diary/features/clip_editor/domain/geotag.dart';
import 'package:one_second_diary/features/clip_editor/domain/trim_selection.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';

/// Where the clip editor is.
enum EditClipStatus {
  /// A video source whose player is not ready: its length is unknown.
  loading,

  ready,

  /// A video source its player cannot open: nothing to trim or save.
  unplayable,
}

/// Where the editor's Save is.
enum SaveStatus {
  idle,

  /// The media engine renders the clip; Cancel stops it.
  rendering,

  /// The render is done and the clip is being filed in the diary: too late
  /// to cancel.
  publishing,

  /// Cancel was tapped; the render is stopping.
  cancelling,

  /// Saved: the editor pops with `EditClipState.saved`.
  saved,

  /// The save failed; nothing in the diary changed.
  failed,
}

/// Why the editor's last Save failed ([SaveStatus.failed]).
enum SaveFailure {
  /// Anything else: worth a bug report.
  unexpected,

  /// The phone ran out of space while the clip was made or filed: nothing
  /// to report, the user frees some space.
  outOfSpace,
}

/// The clip editor: what it opened with, the [draft] the user edits and
/// where it is.
final class EditClipState extends Equatable {
  const EditClipState({
    required this.args,
    required this.status,
    required this.draft,
    this.sourceAspectRatio,
    this.sourceSize,
    this.sourceColorTransfer,
    this.trimming = false,
    this.geotag = const Geotag(),
    this.saveStatus = SaveStatus.idle,
    this.saveProgress = 0,
    this.saveFailure = SaveFailure.unexpected,
    this.saveShortfallBytes,
    this.saved,
    this.placeSaves = 0,
    this.placeSaveFailures = 0,
  });

  final EditClipArgs args;

  final EditClipStatus status;

  final EditClipDraft draft;

  /// The video source's width / height, once its player is ready.
  final double? sourceAspectRatio;

  /// The source's size in pixels, upright, once probed (the framing
  /// sheet's lossless mark and the crop the engine cuts with need it);
  /// null until then, or when it could not be read.
  final SourceSize? sourceSize;

  /// The source's `color_transfer` from the same probe (`arib-std-b67`,
  /// `smpte2084`: an HDR source), passed to the save so the engine
  /// converts the range; null for SDR or until probed.
  final String? sourceColorTransfer;

  /// A finger is on the trim window (moving it or an edge): the preview
  /// shows the window's start instead of playing.
  final bool trimming;

  /// The location switch, the place found and a typed place; the draft's
  /// location follows it.
  final Geotag geotag;

  final SaveStatus saveStatus;

  /// How much of the render is done (0–1) while [saveStatus] is
  /// [SaveStatus.rendering]; 1 once the clip is being filed.
  final double saveProgress;

  /// Why the last Save failed; read once [SaveStatus.failed].
  final SaveFailure saveFailure;

  /// With [SaveFailure.outOfSpace] from the storage budget: how many bytes
  /// to free (`StorageShortException`); null when the phone filled up
  /// while the clip was made.
  final int? saveShortfallBytes;

  /// The clip the Save wrote, once [SaveStatus.saved].
  final SavedClip? saved;

  /// Grows each time "Save this place" saved the clip's place (the page
  /// says so).
  final int placeSaves;

  /// Grows each time a place could not be stored.
  final int placeSaveFailures;

  /// Whether a Save runs (or ended saved, and the editor is closing): the
  /// draft can no longer change, and back is blocked.
  bool get saving => switch (saveStatus) {
    SaveStatus.rendering ||
    SaveStatus.publishing ||
    SaveStatus.cancelling ||
    SaveStatus.saved => true,
    SaveStatus.idle || SaveStatus.failed => false,
  };

  /// The trim window of a video source; null for a photo and while loading.
  TrimSelection? get trim => switch (draft.length) {
    TrimmedVideo(:final TrimSelection trim) => trim,
    _ => null,
  };

  /// How long the saved clip will be (the readout): exactly the window;
  /// null while a video is loading.
  int? get savedLengthMs => switch (draft.length) {
    TrimmedVideo(:final TrimSelection trim) => trim.savedLengthMs,
    HeldPhoto(:final int durationMs) => durationMs,
    null => null,
  };

  /// Whether "Change" is offered: a new clip may go to any profile; a
  /// replace writes over one clip of one profile.
  bool get canChangeProfile => args.mode is AddClip;

  /// Whether Save may run: the source is loaded, no place is being found
  /// (the clip would miss it), and no save runs.
  bool get canSave =>
      status == EditClipStatus.ready &&
      draft.length != null &&
      geotag.status != GeotagStatus.finding &&
      !saving;

  EditClipState copyWith({
    EditClipStatus? status,
    EditClipDraft? draft,
    double? sourceAspectRatio,
    SourceSize? sourceSize,
    String? sourceColorTransfer,
    bool? trimming,
    Geotag? geotag,
    SaveStatus? saveStatus,
    double? saveProgress,
    SaveFailure? saveFailure,
    int? Function()? saveShortfallBytes,
    SavedClip? saved,
    int? placeSaves,
    int? placeSaveFailures,
  }) => EditClipState(
    args: args,
    status: status ?? this.status,
    draft: draft ?? this.draft,
    sourceAspectRatio: sourceAspectRatio ?? this.sourceAspectRatio,
    sourceSize: sourceSize ?? this.sourceSize,
    sourceColorTransfer: sourceColorTransfer ?? this.sourceColorTransfer,
    trimming: trimming ?? this.trimming,
    geotag: geotag ?? this.geotag,
    saveStatus: saveStatus ?? this.saveStatus,
    saveProgress: saveProgress ?? this.saveProgress,
    saveFailure: saveFailure ?? this.saveFailure,
    saveShortfallBytes: saveShortfallBytes == null
        ? this.saveShortfallBytes
        : saveShortfallBytes(),
    saved: saved ?? this.saved,
    placeSaves: placeSaves ?? this.placeSaves,
    placeSaveFailures: placeSaveFailures ?? this.placeSaveFailures,
  );

  @override
  List<Object?> get props => <Object?>[
    args,
    status,
    draft,
    sourceAspectRatio,
    sourceSize,
    sourceColorTransfer,
    trimming,
    geotag,
    saveStatus,
    saveProgress,
    saveFailure,
    saveShortfallBytes,
    saved,
    placeSaves,
    placeSaveFailures,
  ];
}
