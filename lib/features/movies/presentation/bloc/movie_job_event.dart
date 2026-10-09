import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_music.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The movie to make: which clips, from which profile (the flow's own, never
/// necessarily the app's active one), in which format (the profile's,
/// `ProfilesRepository.formatOf`: its canvas and what a clip that differs is
/// normalised into), and its base title (without a profile prefix).
final class MovieJobRequest extends Equatable {
  const MovieJobRequest({
    required this.source,
    required this.profile,
    required this.format,
    required this.title,
    this.clipBytes = 0,
    this.includePrivate = false,
    this.transition,
    this.upgradeOlderClips = false,
    this.music,
  });

  final MovieSource source;
  final ProfileKey profile;

  /// The profile's write-once clip format: the movie's canvas, frame rate
  /// and codec, and what the engine normalises a clip that differs into.
  final ClipFormat format;

  /// The canvas: [format]'s orientation.
  VideoOrientation get orientation => format.orientation;

  final String title;

  /// The clips' size on disk, as the free space was checked with it: a phone
  /// that fills up during the build says how much to free from it. 0 when not
  /// known.
  final int clipBytes;

  /// Whether a range takes the profile's private clips too.
  final bool includePrivate;

  /// The transition between clips; null for hard cuts (the default).
  final MovieTransition? transition;

  /// With [transition], whether clips that cannot be cut at a keyframe are
  /// re-encoded first instead of joining with a hard cut.
  final bool upgradeOlderClips;

  /// Music over (or in place of) the videos' sound; null for none.
  final MovieMusic? music;

  @override
  List<Object?> get props => <Object?>[
    source,
    profile,
    format,
    title,
    clipBytes,
    includePrivate,
    transition,
    upgradeOlderClips,
    music,
  ];
}

/// What the movie flow asks of the `MovieJobBloc`.
sealed class MovieJobEvent extends Equatable {
  const MovieJobEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Makes [request]'s movie. Ignored while one runs.
final class MovieJobStarted extends MovieJobEvent {
  const MovieJobStarted(this.request);

  final MovieJobRequest request;

  @override
  List<Object?> get props => <Object?>[request];
}

/// Stops the running movie; nothing of it is kept. Too late once the movie
/// is being saved (finishing): it is then made anyway.
final class MovieJobCancelled extends MovieJobEvent {
  const MovieJobCancelled();
}

/// The end has been seen (Done, the error's Close, a cancel): back to idle.
/// Ignored while one runs.
final class MovieJobDismissed extends MovieJobEvent {
  const MovieJobDismissed();
}
