import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// One movie in `Movies/` (all profiles share the folder).
final class MovieEntry extends Equatable {
  const MovieEntry({
    required this.fileName,
    required this.title,
    required this.profile,
    required this.clipCount,
    required this.from,
    required this.to,
    required this.createdAt,
    required this.durationMs,
    this.orientation,
    this.privateClipCount = 0,
    this.tags = const <String>[],
    this.without = const <String>[],
    this.chapters = const <MovieChapter>[],
    this.transition,
    this.musicOn,
  });

  /// The path in `Movies/`: `OSD-Movie-12-2024-01-05.mp4`, or
  /// `Trips/OSD-Movie-3-2024-01-05.mp4` for a movie the user moved into a
  /// sub-folder.
  final String fileName;

  /// The BASE title, without a profile prefix.
  final String title;

  /// The profile it was made from (also in the MP4 comment as
  /// `profile=<key>`); null for movies made by older installs.
  final ProfileKey? profile;

  final int? clipCount;

  /// First and last day covered.
  final LocalDay? from;
  final LocalDay? to;

  /// When it was made (the file's modification time for movies made by
  /// older installs).
  final DateTime createdAt;

  final int? durationMs;

  /// Its canvas: the profile's, or the frame's once probed for a movie made by
  /// an older install; null while unknown (screens then draw it landscape).
  final VideoOrientation? orientation;

  /// How many of its clips were private when it was made (also in the MP4
  /// description as `private=<n>`): My movies marks such a movie, so it is not
  /// shared by mistake. 0 for a movie without any, and for one made by an older
  /// install.
  final int privateClipCount;

  /// The tags its clips were chosen by ("only videos tagged…"; also in the MP4
  /// description as `tags=a,b`); empty for a movie made without, and for one
  /// made by an older install.
  final List<String> tags;

  /// The tags its clips were chosen to lack ("leave out videos tagged…";
  /// `without=c` in the MP4 description); empty when made without.
  final List<String> without;

  /// Whether a tag filter chose its clips: My movies marks such a movie.
  bool get hasTagFilter => tags.isNotEmpty || without.isNotEmpty;

  /// Its chapters, one per clip in movie order (also in the MP4 as
  /// chapters); empty for a movie made by an older install until probed.
  final List<MovieChapter> chapters;

  /// The transition its clips were joined with (also in the MP4 description as
  /// `transition=<tag>`); null for a movie of hard cuts, and for one made by an
  /// older install.
  final MovieTransition? transition;

  /// Whether the movie's music plays: it was made with music (`MovieMusic`), so
  /// it carries two audio tracks, the mix and the videos' own sound, and this
  /// says which is first and default (also in the MP4 description as
  /// `music=on|off`).
  final bool? musicOn;

  /// Whether the movie carries music at all (on or off).
  bool get hasMusic => musicOn != null;

  /// This movie with its music playing, or not: the file was remuxed so
  /// the other audio track is first and default.
  MovieEntry withMusicOn({required bool on}) => MovieEntry(
    fileName: fileName,
    title: title,
    profile: profile,
    clipCount: clipCount,
    from: from,
    to: to,
    createdAt: createdAt,
    durationMs: durationMs,
    orientation: orientation,
    privateClipCount: privateClipCount,
    tags: tags,
    without: without,
    chapters: chapters,
    transition: transition,
    musicOn: on,
  );

  /// The chapter playing at [positionMs], or null without chapters.
  MovieChapter? chapterAt(int positionMs) {
    MovieChapter? current;
    for (final MovieChapter chapter in chapters) {
      if (chapter.startMs > positionMs) break;
      current = chapter;
    }
    return current;
  }

  /// The title screens show: [title] prefixed with the CURRENT display name of
  /// a non-Default [profile], as [displayNameOf] gives it ("Kids · 2025").
  String displayTitle(String? Function(ProfileKey profile) displayNameOf) =>
      switch (profile) {
        final ProfileKey owner when !owner.isDefault =>
          '${displayNameOf(owner) ?? owner.value} · $title',
        _ => title,
      };

  /// This movie with base title [title]: only the title changes, never the
  /// file.
  MovieEntry withTitle(String title) => MovieEntry(
    fileName: fileName,
    title: title,
    profile: profile,
    clipCount: clipCount,
    from: from,
    to: to,
    createdAt: createdAt,
    durationMs: durationMs,
    orientation: orientation,
    privateClipCount: privateClipCount,
    tags: tags,
    without: without,
    chapters: chapters,
    transition: transition,
    musicOn: musicOn,
  );

  @override
  List<Object?> get props => <Object?>[
    fileName,
    title,
    profile,
    clipCount,
    from,
    to,
    createdAt,
    durationMs,
    orientation,
    privateClipCount,
    tags,
    without,
    chapters,
    transition,
    musicOn,
  ];
}
