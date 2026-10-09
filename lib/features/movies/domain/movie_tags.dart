import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// What a movie file says about itself: its MP4 tags and frame, as ffprobe
/// reads them.
final class MovieTags extends Equatable {
  const MovieTags({
    this._title,
    this.comment,
    this.description,
    this.durationMs,
    this.width,
    this.height,
    this.chapters = const <MovieChapter>[],
  });

  final String? _title;

  final String? comment;

  final String? description;

  /// The container's duration.
  final int? durationMs;

  /// The video stream's size.
  final int? width;
  final int? height;

  /// The chapters the file carries, one per clip in movie order; empty
  /// for a movie made by an older install.
  final List<MovieChapter> chapters;

  static const String _profilePrefix = 'profile=';

  /// The key of the music part of the description.
  static const String musicKey = 'music';

  /// The `description` of a movie of [clips] clips from [from] to [to],
  /// [privateClips] of them private (said only when there are any), chosen as
  /// the clips tagged one of [tags] and none of [without] (each said only when
  /// given), with `;music=on` when the movie is made [withMusic] (a second
  /// audio track, playing).
  static String describe({
    required int clips,
    required LocalDay from,
    required LocalDay to,
    int privateClips = 0,
    Iterable<String> tags = const <String>[],
    Iterable<String> without = const <String>[],
    bool withMusic = false,
  }) =>
      'clips=$clips;from=${from.fileStem};to=${to.fileStem}'
      '${privateClips > 0 ? ';private=$privateClips' : ''}'
      '${_tagsPart('tags', tags)}'
      '${_tagsPart('without', without)}'
      '${withMusic ? ';$musicKey=on' : ''}';

  /// [description] with its music part saying [on] (`music=on` / `off`), every
  /// other part kept in its place: the part is rewritten where it is, or
  /// appended when there is none (a movie whose tags said nothing of music gets
  /// the part at the end; an empty or null description becomes the part alone).
  static String withMusic(String? description, {required bool on}) {
    final String part = '$musicKey=${on ? 'on' : 'off'}';
    final List<String> parts = <String>[
      for (final String existing in (description ?? '').split(';'))
        if (existing.isNotEmpty) existing,
    ];
    bool rewritten = false;
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].startsWith('$musicKey=')) {
        parts[i] = part;
        rewritten = true;
      }
    }
    if (!rewritten) parts.add(part);
    return parts.join(';');
  }

  static String _tagsPart(String key, Iterable<String> tags) {
    final List<String> clean = sorted(<String>[
      for (final String tag in tags)
        if (tag.replaceAll(';', ' ').trim() case final String tag
            when tag.isNotEmpty)
          tag,
    ]);
    return clean.isEmpty ? '' : ';$key=${clean.join(',')}';
  }

  /// [tags] in the order the description writes them (by fold key), so a
  /// movie entry equals what its file says.
  static List<String> sorted(Iterable<String> tags) =>
      List<String>.unmodifiable(
        tags.toList()..sort(
          (String a, String b) => TagName.fold(a).compareTo(TagName.fold(b)),
        ),
      );

  /// The base title; null when the tag is missing or blank.
  String? get title => switch (_title?.trim()) {
    final String title when title.isNotEmpty => title,
    _ => null,
  };

  /// The profile named in the comment (`profile=` is Default); null for any
  /// other comment.
  ProfileKey? get profile => switch (comment) {
    final String text when text.startsWith(_profilePrefix) => ProfileKey(
      text.substring(_profilePrefix.length),
    ),
    _ => null,
  };

  /// The clips the description counts; null unless it is whole.
  int? get clipCount => _described?.clips;

  /// The first day the description covers; null unless it is whole.
  LocalDay? get from => _described?.from;

  /// The last day the description covers; null unless it is whole.
  LocalDay? get to => _described?.to;

  /// The private clips the description counts; 0 when it counts none.
  int get privateClipCount => switch (int.tryParse(_parts['private'] ?? '')) {
    final int count when count > 0 => count,
    _ => 0,
  };

  /// The tags the movie's clips were chosen by ("only videos tagged…");
  /// empty when it was made without.
  List<String> get tags => _tagList('tags');

  /// The tags the movie's clips were chosen to lack ("leave out videos
  /// tagged…"); empty when it was made without.
  List<String> get without => _tagList('without');

  /// The transition its clips were joined with (`transition=<tag>`); null
  /// for a movie of hard cuts, and for an unknown tag.
  MovieTransition? get transition =>
      MovieTransition.fromTag(_parts[MovieTransition.descriptionKey]);

  /// Whether the movie's music plays (`music=on`, true), is turned off
  /// (`music=off`, false), or the movie has no music (null: no part, or an
  /// unknown value).
  bool? get musicOn => switch (_parts[musicKey]) {
    'on' => true,
    'off' => false,
    _ => null,
  };

  /// The canvas the frame has; null while its size is unknown.
  VideoOrientation? get orientation => switch ((width, height)) {
    (final int width, final int height) when width > 0 && height > 0 =>
      width >= height ? VideoOrientation.landscape : VideoOrientation.portrait,
    _ => null,
  };

  /// The three parts of a [describe]d description, in any order; null when one
  /// is missing or wrong (a count below 1, an impossible day, days the wrong
  /// way round).
  ({int clips, LocalDay from, LocalDay to})? get _described {
    if (description == null) return null;
    final Map<String, String> parts = _parts;
    final int? clips = int.tryParse(parts['clips'] ?? '');
    final LocalDay? from = LocalDay.tryParseStem(parts['from'] ?? '');
    final LocalDay? to = LocalDay.tryParseStem(parts['to'] ?? '');
    if (clips == null || clips < 1 || from == null || to == null) return null;
    if (to.compareTo(from) < 0) return null;
    return (clips: clips, from: from, to: to);
  }

  List<String> _tagList(String key) => List<String>.unmodifiable(<String>[
    for (final String tag in (_parts[key] ?? '').split(','))
      if (tag.trim() case final String tag when tag.isNotEmpty) tag,
  ]);

  /// The `key=value` parts of the description.
  Map<String, String> get _parts => <String, String>{
    for (final String part in (description ?? '').split(';'))
      if (part.indexOf('=') case final int at when at > 0)
        part.substring(0, at): part.substring(at + 1),
  };

  @override
  List<Object?> get props => <Object?>[
    _title,
    comment,
    description,
    durationMs,
    width,
    height,
    chapters,
  ];
}
