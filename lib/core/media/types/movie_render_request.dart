import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/movie_music.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

/// A movie to build: a stream-copy join of [clips], in the given order.
final class MovieRenderRequest extends Equatable {
  const MovieRenderRequest({
    required this.clips,
    required this.format,
    required this.outputPath,
    required this.title,
    required this.comment,
    this.description,
    this.excludePrivate = false,
    this.transition,
    this.upgradeOlderClips = false,
    this.music,
  });

  /// The clips, already in movie order (chronological, then by ordinal).
  /// At least two.
  final List<MovieClip> clips;

  /// The format mismatched clips are normalised to:
  /// `ClipFormat.legacy(orientation)` joins and normalises exactly as every
  /// earlier version did.
  final ClipFormat format;

  /// The canvas: [format]'s orientation.
  VideoOrientation get orientation => format.orientation;

  /// Absolute path of the movie to create. Must not exist yet: movies are
  /// never overwritten.
  final String outputPath;

  /// The movie's `title` metadata: its BASE title, without any profile
  /// prefix (screens add the profile's current display name).
  final String? title;

  /// The movie's `comment` metadata: `profile=<ProfileKey.value>`
  /// (`profile=` is Default). Always the immutable key, never the display
  /// name, so a profile rename never makes it stale.
  final String? comment;

  /// The movie's `description` metadata: its clips and days,
  /// `clips=<n>;from=<yyyy-MM-dd>;to=<yyyy-MM-dd>`, so a reinstall that
  /// loses the movie index can still count them.
  final String? description;

  /// Whether a clip the engine has to probe (its facts are not known) and
  /// finds private (`ClipPrivacyTag`) is left out: the caller already left
  /// out the clips it knows are private, and this covers a clip whose file
  /// nobody has read yet (`MovieCompleted.leftOutPrivate`).
  final bool excludePrivate;

  /// The transition between clips, or null for hard cuts (the stream-copy
  /// join of every earlier version, byte for byte). With one, each
  /// boundary whose two clips can be cut at keyframes (`TransitionPolicy`)
  /// gets the transition; the others stay hard cuts.
  final MovieTransition? transition;

  /// With [transition], whether a clip that cannot be cut at keyframes (one
  /// saved before 2.1 by libx264) is re-encoded into a cut-able copy first
  /// (kept in the normalised-copy cache), instead of joining with a hard
  /// cut. Slow on Android: a full re-encode per such clip.
  final bool upgradeOlderClips;

  /// Music over (or in place of) the videos' sound, or null for none: the
  /// movie then has the one audio track of every earlier version. With
  /// music the movie carries two audio tracks (`MovieMusic`).
  final MovieMusic? music;

  @override
  List<Object?> get props => <Object?>[
    clips,
    format,
    outputPath,
    title,
    comment,
    description,
    excludePrivate,
    transition,
    upgradeOlderClips,
    music,
  ];
}
