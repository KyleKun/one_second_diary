import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_privacy_tag.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/keywords_tag.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/media/types/osd_artist.dart';

/// What ffprobe reports about a clip or a movie: stream layout, size and
/// the raw tags.
///
/// The metadata backfill turns it into `ClipMeta` once per clip; movie
/// planning uses `MovieClip`, never this. Movies are probed too, to rebuild
/// the movie index after a reinstall ([title], [comment], [description],
/// [chapters]).
final class ClipProbe extends Equatable {
  const ClipProbe({
    required this.durationMs,
    required this.hasAudio,
    required this.hasSubtitleStream,
    required this.artist,
    required this.album,
    required this.comment,
    required this.locationTag,
    required this.title,
    required this.width,
    required this.height,
    required this.codec,
    required this.fps,
    this.channels,
    this.pixelFormat,
    this.colorTransfer,
    this.description,
    this.keywords,
    this.synopsis,
    this.chapters = const <MovieChapter>[],
  });

  /// Container duration; null when ffprobe did not report one.
  final int? durationMs;

  final bool hasAudio;
  final bool hasSubtitleStream;

  /// Raw `artist` tag (see [schema]).
  final String? artist;

  /// Raw `album` tag: `Default` or the profile's folder key.
  final String? album;

  /// Raw `comment` tag: `origin=gallery` on a clip (see [origin]),
  /// `profile=<key>` on a movie.
  final String? comment;

  /// Raw `location` tag, `<±lat><±lon>/<place>`. Decode it with the
  /// `LocationTag` codec, never by hand.
  final String? locationTag;

  /// Raw `title` tag (a movie's base title); null on clips.
  final String? title;

  /// Raw `description` tag: a movie's clips and days,
  /// `clips=<n>;from=<yyyy-MM-dd>;to=<yyyy-MM-dd>` (plus `private=<n>` when
  /// it holds private clips), or `private=1` on a private clip (see
  /// [isPrivate]); null on public clips and on movies made by older
  /// installs.
  final String? description;

  /// Raw `keywords` tag: the clip's tags, comma-separated (see [tags]);
  /// null on a clip without tags.
  final String? keywords;

  /// Raw `synopsis` tag: the phone and moment the clip was made
  /// (`ClipNotesTag`); null on clips saved without it.
  final String? synopsis;

  /// Video stream size and codec (`h264`, …).
  final int? width;
  final int? height;
  final String? codec;

  /// Video stream frame rate (30 for every [ClipSchema.v15] clip).
  final double? fps;

  /// Audio stream channel count (1 or 2); null without an audio stream or
  /// when ffprobe did not report it.
  final int? channels;

  /// Video stream pixel format as ffprobe names it (`yuv420p`,
  /// `yuv420p10le`); null when not reported.
  final String? pixelFormat;

  /// Video stream colour transfer as ffprobe names it (`bt709`;
  /// `arib-std-b67` and `smpte2084` are HDR); null when not reported, as
  /// most SDR phone recordings leave it.
  final String? colorTransfer;

  /// A movie's chapters, one per clip, in the file's order
  /// (`-show_chapters`); empty on a clip and on a movie made
  /// by an older install.
  final List<MovieChapter> chapters;

  /// Which clip contract the artist tag says the clip was written under
  /// (`ClipSchema.fromArtist`): [osdArtist] → v1.5, `osdArtistV2` → v2,
  /// anything else → other (not ours).
  ClipSchema get schema => ClipSchema.fromArtist(artist);

  /// Whether the artist tag contains [osdArtist] ([schema] v1.5). Any
  /// other clip needs normalising (on a copy) before a movie.
  bool get isOsdV15 => schema == ClipSchema.v15;

  /// Where the clip came from, when its comment tag says so.
  ClipOrigin? get origin => ClipOrigin.fromComment(comment);

  /// Whether the clip's description tag marks it private.
  bool get isPrivate => ClipPrivacyTag.isPrivate(description);

  /// The clip's tags, in the file's order; empty without a `keywords` tag.
  List<String> get tags => KeywordsTag.parse(keywords);

  @override
  List<Object?> get props => <Object?>[
    durationMs,
    hasAudio,
    hasSubtitleStream,
    artist,
    album,
    comment,
    locationTag,
    title,
    description,
    keywords,
    synopsis,
    width,
    height,
    codec,
    fps,
    channels,
    pixelFormat,
    colorTransfer,
    chapters,
  ];
}
