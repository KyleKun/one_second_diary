import 'package:one_second_diary/core/media/types/osd_artist.dart';

/// Which version of the app's clip contract a clip was written under, from
/// its `artist` tag (the schema marker).
enum ClipSchema {
  /// `One Second Diary (v1.5)`: the legacy format (1080p H.264 30 fps
  /// mono SDR), the only marker older builds join raw.
  v15,

  /// `One Second Diary (v2)`: any other format. Older builds normalise
  /// such a clip before a movie, never join it raw.
  v2,

  /// Not ours: a foreign or pre-v1.5 clip (badged "Imported").
  other;

  /// The schema of a clip whose artist tag is [artist]. The marker counts
  /// wherever it sits in the tag.
  static ClipSchema fromArtist(String? artist) {
    if (artist == null) return ClipSchema.other;
    if (artist.contains(osdArtist)) return ClipSchema.v15;
    if (artist.contains(osdArtistV2)) return ClipSchema.v2;
    return ClipSchema.other;
  }

  /// The schema stored as [name], or null for anything unknown.
  static ClipSchema? parse(String? name) => values.asNameMap()[name];
}
