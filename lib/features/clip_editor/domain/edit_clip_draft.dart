import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show ValueGetter;
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clip_editor/domain/canvas_frame.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Everything the user edits before a save: what the render and the store
/// need beyond the source and the day.
final class EditClipDraft extends Equatable {
  const EditClipDraft({
    required this.profile,
    required this.length,
    required this.stamp,
    required this.location,
    required this.subtitles,
    this.frame,
    this.tags = const <String>[],
    this.mute = false,
    this.zoom = true,
  });

  /// The profile this clip goes to; changing it here leaves the active
  /// profile as it is.
  final ProfileKey profile;

  /// The trim window or the photo's length; null while a video source is
  /// still loading (its duration is not known yet).
  final ClipLength? length;

  final StampStyle stamp;

  final ClipLocation location;

  /// The soft subtitle; `''` for none.
  final String subtitles;

  /// The framing sheet's frame and the canvas it was made for; null frames
  /// the source by default (`ClipFrameGeometry.defaultFrame`: fitted into
  /// a landscape canvas, covering a portrait one).
  final CanvasFrame? frame;

  /// The clip's tags, as the tags sheet left them (normalised at the
  /// render, `TagName.normalize`); empty for none.
  final List<String> tags;

  /// Whether the clip is saved without its sound (a silent track in its
  /// place, `ClipRenderRequest.mute`); only a video source offers it.
  final bool mute;

  /// Whether a photo slowly zooms in over the clip (`PhotoRender.zoom`);
  /// only a photo source offers it.
  final bool zoom;

  /// The frame a clip made in [canvas] gets: the one made for that canvas,
  /// if any.
  ClipFrame? frameFor(VideoOrientation canvas) =>
      frame?.canvas == canvas ? frame?.frame : null;

  /// A copy with the given fields; [frame] takes a getter, so it can be
  /// cleared (`frame: () => null`).
  EditClipDraft copyWith({
    ProfileKey? profile,
    ClipLength? length,
    StampStyle? stamp,
    ClipLocation? location,
    String? subtitles,
    ValueGetter<CanvasFrame?>? frame,
    List<String>? tags,
    bool? mute,
    bool? zoom,
  }) => EditClipDraft(
    profile: profile ?? this.profile,
    length: length ?? this.length,
    stamp: stamp ?? this.stamp,
    location: location ?? this.location,
    subtitles: subtitles ?? this.subtitles,
    frame: frame != null ? frame() : this.frame,
    tags: tags ?? this.tags,
    mute: mute ?? this.mute,
    zoom: zoom ?? this.zoom,
  );

  @override
  List<Object?> get props => <Object?>[
    profile,
    length,
    stamp,
    location,
    subtitles,
    frame,
    tags,
    mute,
    zoom,
  ];
}
