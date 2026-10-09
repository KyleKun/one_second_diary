/// The transition between two clips of a movie, when the user asks for
/// one (`MovieRenderRequest.transition`; none by default). Every style is
/// an ffmpeg `xfade` transition over `TransitionPolicy.frames` frames, with
/// the audio crossfaded over the same span.
enum MovieTransition {
  /// A dissolve: the next clip fades in over the end of the one before.
  crossfade('fade', 'fade'),

  /// A dip through black.
  fadeBlack('fadeblack', 'black'),

  /// A dip through white.
  fadeWhite('fadewhite', 'white');

  const MovieTransition(this.xfadeName, this.tag);

  /// The `xfade=transition=<name>` value.
  final String xfadeName;

  /// The value written into the movie's `description` tag
  /// (`transition=<tag>`) and the movie index.
  final String tag;

  /// The key of that part of the `description`.
  static const String descriptionKey = 'transition';

  /// The `description` part the engine appends to a movie it joined with
  /// at least one transition (`transition=fade`); a movie asked for one
  /// whose every boundary stayed a hard cut carries none, so the tag says
  /// what the file holds.
  String get descriptionPart => '$descriptionKey=$tag';

  /// The style [tag] names; null for an unknown or missing tag.
  static MovieTransition? fromTag(String? tag) {
    for (final MovieTransition style in values) {
      if (style.tag == tag) return style;
    }
    return null;
  }
}
