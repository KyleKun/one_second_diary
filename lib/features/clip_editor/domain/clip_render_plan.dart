import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length.dart';
import 'package:one_second_diary/features/clip_editor/domain/edit_clip_draft.dart';
import 'package:one_second_diary/features/clip_editor/domain/trim_selection.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';

/// What the screen knows when Save is tapped, and the draft does not: the date stamp's text as the preview shows it
/// and the format of the profile the clip goes to.
final class ClipRenderLook extends Equatable {
  const ClipRenderLook({required this.stampText, required this.format});

  /// The date the export burns in, formatted for the day the clip is filed
  /// under.
  final String stampText;

  /// The profile's write-once format.
  final ClipFormat format;

  /// The profile's canvas.
  VideoOrientation get orientation => format.orientation;

  @override
  List<Object?> get props => <Object?>[stampText, format];
}

/// The size of a source, in whole pixels, upright.
typedef SourceSize = ({int width, int height});

/// What one probe of a source says: its size as the file stores it, and
/// its `color_transfer` (`arib-std-b67` or `smpte2084` for an HDR source,
/// null for SDR or untagged), which decides the save's range conversion
/// (`RangeFilter`).
typedef SourceFacts = ({int width, int height, String? colorTransfer});

/// The render the editor's Save asks the media engine for; the engine owns the ffmpeg arguments.
/// The trim window ends exactly where the selection ends; `album` is the profile's key, never its display name.
abstract final class ClipRenderPlan {
  /// The request for [draft], made from [source] and filed under [day].
  ///
  /// The file name is the day's first clip name for an [AddClip] (the store picks the free ordinal) and the replaced clip's for a [ReplaceClip].
  /// A draft whose video length is unknown throws a [StateError].
  /// The framing goes as a [SourceFrame] with [sourceSize] (the engine's `frameFilter` needs it); without a size the engine fits the source by default.
  /// [sourceColorTransfer] (null: SDR) drives HDR tone-mapping into SDR profiles and SDR into HLG.
  ///
  /// [imported] marks a processed import ("Edit again" on one): the engine writes `origin=import` and takes the import's audio path.
  static ClipRenderRequest of({
    required ClipSource source,
    required LocalDay day,
    required ClipSaveMode mode,
    required EditClipDraft draft,
    required bool legacyStampFont,
    required ClipRenderLook look,
    SourceSize? sourceSize,
    bool imported = false,
    String? sourceColorTransfer,
  }) {
    final String outputFileName = switch (mode) {
      AddClip() => ClipNameCodec.format(day),
      ReplaceClip(:final ClipRef clip) => PathNames.fileNameOf(clip.relPath),
    };
    final SourceFrame? frame = sourceFrameOf(
      draft.frameFor(look.orientation),
      sourceSize: sourceSize,
    );
    return switch ((source, draft.length)) {
      (
        VideoSource(:final String path, :final bool fromRecording),
        TrimmedVideo(:final TrimSelection trim),
      ) =>
        VideoRender(
          sourcePath: path,
          fromRecording: fromRecording,
          imported: imported,
          trimStartMs: trim.startMs,
          trimEndMs: trim.savedEndMs,
          outputFileName: outputFileName,
          stampText: look.stampText,
          stampStyle: draft.stamp,
          legacyStampFont: legacyStampFont,
          location: draft.location,
          subtitles: draft.subtitles,
          format: look.format,
          albumLabel: draft.profile.albumLabel,
          frame: frame,
          tags: TagName.normalize(draft.tags),
          mute: draft.mute,
          sourceColorTransfer: sourceColorTransfer,
        ),
      (PhotoSource(:final String path), HeldPhoto(:final int durationMs)) =>
        PhotoRender(
          photoPath: path,
          durationSeconds: durationMs / 1000,
          zoom: draft.zoom,
          outputFileName: outputFileName,
          stampText: look.stampText,
          stampStyle: draft.stamp,
          legacyStampFont: legacyStampFont,
          location: draft.location,
          subtitles: draft.subtitles,
          format: look.format,
          albumLabel: draft.profile.albumLabel,
          frame: frame,
          tags: TagName.normalize(draft.tags),
        ),
      _ => throw StateError('Nothing to render yet: ${draft.length}'),
    };
  }

  /// [frame] with the source's [sourceSize], as the engine reads it; null
  /// without a frame or without the size.
  static SourceFrame? sourceFrameOf(
    ClipFrame? frame, {
    required SourceSize? sourceSize,
  }) {
    if (frame == null || sourceSize == null) return null;
    return SourceFrame(
      frame: frame,
      sourceWidth: sourceSize.width,
      sourceHeight: sourceSize.height,
    );
  }
}
