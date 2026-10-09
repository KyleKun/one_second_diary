import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_crop.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/color_transfer.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

/// Everything the media engine needs to turn a source into a day clip.
///
/// The engine renders into its private scratch folder and returns a
/// `RenderedClip`; it never writes into the gallery. Publishing, replacing
/// and Undo are the caller's job.
sealed class ClipRenderRequest extends Equatable {
  const ClipRenderRequest({
    required this.outputFileName,
    required this.stampText,
    required this.stampStyle,
    required this.legacyStampFont,
    required this.location,
    required this.subtitles,
    required this.format,
    required this.albumLabel,
    this.crop,
    this.frame,
    this.isPrivate = false,
    this.tags = const <String>[],
    this.deviceTag,
    this.mute = false,
    this.sourceColorTransfer,
  });

  /// Basename the published clip will have (`yyyy-MM-dd.mp4` or
  /// `yyyy-MM-dd-N.mp4`). The rendered temp file carries the same name,
  /// because Android's media store publishes under the temp file's name.
  final String outputFileName;

  /// The date text to burn in, already formatted (numeric or written, in the
  /// app language) for the day the clip is filed under.
  final String stampText;

  final StampStyle stampStyle;

  /// The "legacy font" preference: the stamps prefer Yusei Magic, as older
  /// versions burned them (`StampFontPolicy`).
  final bool legacyStampFont;

  final ClipLocation location;

  /// Soft subtitle text; `''` means no subtitle stream.
  final String subtitles;

  /// The profile's format: canvas, codec, frame rate, audio layout and
  /// range. `ClipFormat.legacy(orientation)` produces every
  /// argv of earlier versions byte for byte.
  final ClipFormat format;

  /// The profile's canvas: [format]'s orientation.
  VideoOrientation get orientation => format.orientation;

  /// The part of the source the clip keeps, filling the canvas; null fits
  /// the whole source to the canvas (`CanvasFilter.scaleFilter`). Ignored
  /// when [frame] is given.
  final ClipCrop? crop;

  /// How the source sits on the canvas: zoomed
  /// from fit (bars, black or blurred) to a close crop, and moved, with
  /// the source's size so the filter is computed in whole pixels
  /// (`CanvasFilter.frameFilter`). Null keeps [crop]'s behaviour, the argv
  /// of earlier versions.
  final SourceFrame? frame;

  /// The `album` metadata: `Default` for the Default profile (the empty
  /// key), otherwise the profile's folder key. Never the display name, so a
  /// rename never changes the tags.
  final String albumLabel;

  /// Whether the clip is private (`description=private=1`): true when it
  /// takes the place of a private clip, so the day's clip stays private.
  final bool isPrivate;

  /// The clip's tags (`keywords=…`, `KeywordsTag`), already normalised by
  /// `TagName`; empty writes no tag. Typed in the editor, or carried over
  /// from the clip this one takes the place of.
  final List<String> tags;

  /// The `synopsis` metadata value (`ClipNotesTag`): the phone and the
  /// moment, when the "Device info in videos" preference is on; null
  /// writes no tag.
  final String? deviceTag;

  /// Whether the clip is saved without its sound: a silent track takes the
  /// source's audio's place and the notes tag says `muted=1`
  /// (`ClipNotesTag`). For a recording whose sound came out wrong.
  final bool mute;

  /// The source's `color_transfer` as ffprobe reports it (`arib-std-b67`,
  /// `smpte2084`: HDR; `bt709` or null: SDR), decided by the caller's
  /// probe of the source (the editor's `ClipSaver.sourceFacts`, the import
  /// processor's facts, a kept source's recipe), so the engine knows
  /// whether the save converts the range (`RangeFilter`). Null is SDR: an unknown source is never taken for HDR, so the
  /// argv of an SDR save never changes. Photos are always SDR (the still
  /// converter writes 8-bit PNG).
  final String? sourceColorTransfer;

  /// Whether the source is HDR ([sourceColorTransfer]).
  bool get sourceIsHdr => ColorTransfer.isHdr(sourceColorTransfer);

  /// The `comment=origin=…` metadata value.
  ClipOrigin get origin;

  /// This request for a private clip ([isPrivate]).
  ClipRenderRequest asPrivate();

  /// This request with [tags] (replacing any it had).
  ClipRenderRequest withTags(List<String> tags);

  /// This request with [deviceTag] as its `synopsis` (null: none).
  ClipRenderRequest withDeviceTag(String? deviceTag);

  List<Object?> get _commonProps => <Object?>[
    outputFileName,
    stampText,
    stampStyle,
    legacyStampFont,
    location,
    subtitles,
    format,
    albumLabel,
    crop,
    frame,
    isPrivate,
    tags,
    deviceTag,
    mute,
    sourceColorTransfer,
  ];
}

/// A video (camera recording, gallery or imported video) to trim, stamp
/// and encode.
final class VideoRender extends ClipRenderRequest {
  const VideoRender({
    required this.sourcePath,
    required this.fromRecording,
    required this.trimStartMs,
    required this.trimEndMs,
    required super.outputFileName,
    required super.stampText,
    required super.stampStyle,
    required super.legacyStampFont,
    required super.location,
    required super.subtitles,
    required super.format,
    required super.albumLabel,
    super.crop,
    super.frame,
    super.isPrivate,
    super.tags,
    super.deviceTag,
    super.mute,
    super.sourceColorTransfer,
    this.imported = false,
  });

  final String sourcePath;

  /// Recorded by the app's camera or the system camera (never probed for a
  /// missing audio track).
  final bool fromRecording;

  /// A video found in the diary folder that another app put there
  ///: its origin is `import`. Never with
  /// [fromRecording].
  final bool imported;

  /// Input-side trim start, in ms.
  final int trimStartMs;

  /// Input-side trim end, in ms: exactly the selection (no
  /// pad), floored and clamped to the source duration by the caller
  /// (`ClipTrimPolicy`).
  final int trimEndMs;

  @override
  ClipOrigin get origin => fromRecording
      ? ClipOrigin.osdRecording
      : imported
      ? ClipOrigin.import
      : ClipOrigin.gallery;

  @override
  VideoRender asPrivate() => _copy(isPrivate: true);

  @override
  VideoRender withDeviceTag(String? deviceTag) =>
      _copy(deviceTag: deviceTag, clearDeviceTag: deviceTag == null);

  @override
  VideoRender withTags(List<String> tags) => _copy(tags: tags);

  VideoRender _copy({
    bool? isPrivate,
    List<String>? tags,
    String? deviceTag,
    bool clearDeviceTag = false,
  }) => VideoRender(
    sourcePath: sourcePath,
    fromRecording: fromRecording,
    trimStartMs: trimStartMs,
    trimEndMs: trimEndMs,
    outputFileName: outputFileName,
    stampText: stampText,
    stampStyle: stampStyle,
    legacyStampFont: legacyStampFont,
    location: location,
    subtitles: subtitles,
    format: format,
    albumLabel: albumLabel,
    crop: crop,
    frame: frame,
    isPrivate: isPrivate ?? this.isPrivate,
    tags: tags ?? this.tags,
    deviceTag: clearDeviceTag ? null : deviceTag ?? this.deviceTag,
    mute: mute,
    sourceColorTransfer: sourceColorTransfer,
    imported: imported,
  );

  @override
  List<Object?> get props => <Object?>[
    ..._commonProps,
    sourcePath,
    fromRecording,
    imported,
    trimStartMs,
    trimEndMs,
  ];
}

/// A still photo looped into a clip.
final class PhotoRender extends ClipRenderRequest {
  const PhotoRender({
    required this.photoPath,
    required this.durationSeconds,
    this.zoom = false,
    required super.outputFileName,
    required super.stampText,
    required super.stampStyle,
    required super.legacyStampFont,
    required super.location,
    required super.subtitles,
    required super.format,
    required super.albumLabel,
    super.crop,
    super.frame,
    super.isPrivate,
    super.tags,
    super.deviceTag,
    super.mute,
    super.sourceColorTransfer,
  });

  final String photoPath;

  /// Clip length: 1, 1.5, 2, 3, 5 or 10 s.
  final double durationSeconds;

  /// Whether the photo slowly zooms in over the clip (`PhotoZoom`).
  final bool zoom;

  @override
  ClipOrigin get origin => ClipOrigin.galleryPhoto;

  @override
  PhotoRender asPrivate() => _copy(isPrivate: true);

  @override
  PhotoRender withDeviceTag(String? deviceTag) =>
      _copy(deviceTag: deviceTag, clearDeviceTag: deviceTag == null);

  @override
  PhotoRender withTags(List<String> tags) => _copy(tags: tags);

  PhotoRender _copy({
    bool? isPrivate,
    List<String>? tags,
    String? deviceTag,
    bool clearDeviceTag = false,
  }) => PhotoRender(
    photoPath: photoPath,
    durationSeconds: durationSeconds,
    zoom: zoom,
    outputFileName: outputFileName,
    stampText: stampText,
    stampStyle: stampStyle,
    legacyStampFont: legacyStampFont,
    location: location,
    subtitles: subtitles,
    format: format,
    albumLabel: albumLabel,
    crop: crop,
    frame: frame,
    isPrivate: isPrivate ?? this.isPrivate,
    tags: tags ?? this.tags,
    deviceTag: clearDeviceTag ? null : deviceTag ?? this.deviceTag,
    mute: mute,
    sourceColorTransfer: sourceColorTransfer,
  );

  @override
  List<Object?> get props => <Object?>[
    ..._commonProps,
    photoPath,
    durationSeconds,
    zoom,
  ];
}
