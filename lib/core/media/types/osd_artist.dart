/// The `artist` metadata of every clip the app saves in the legacy format
/// (1080p H.264 30 fps mono SDR): the clip format's schema marker, not a
/// credit (`ClipSchema.v15`).
///
/// Older builds join raw any clip whose artist tag contains this string and
/// normalise a copy of every other. NEVER change it: every existing clip
/// would then need that slow path.
const String osdArtist = 'One Second Diary (v1.5)';

/// The `artist` metadata of every clip saved in any other format
/// (`ClipSchema.v2`). One string, not the format: the facts come from the
/// probe. Older builds normalise such clips, so a new format never corrupts
/// one of their movies.
const String osdArtistV2 = 'One Second Diary (v2)';
