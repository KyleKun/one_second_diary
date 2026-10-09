import 'package:equatable/equatable.dart';

/// One chapter of a movie: one clip, from [startMs] to [endMs] of the
/// movie, titled with the clip's day and, when known, its place and
/// subtitle ("August 27, 2023 · Berlin · eating bananas with friends").
///
/// Written into the movie as MP4 chapters (`FfmetadataChapters`), read back
/// by ffprobe (`-show_chapters`) after a reinstall, and kept in the movie
/// index so the player can show and jump to them.
final class MovieChapter extends Equatable {
  const MovieChapter({
    required this.startMs,
    required this.endMs,
    required this.title,
  });

  final int startMs;
  final int endMs;
  final String title;

  int get durationMs => endMs - startMs;

  @override
  List<Object?> get props => <Object?>[startMs, endMs, title];
}
