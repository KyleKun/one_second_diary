/// Whether a clip is private, as written into its `description` metadata
/// (`description=private=1`). The tag is part of the clip format contract:
/// it travels with the file, so a private clip is still private after a
/// reinstall or on another phone.
///
/// The value is one `key=value` part of a `;`-separated list, like a
/// movie's description, so another part can join it later. A public clip
/// has no `description` at all.
abstract final class ClipPrivacyTag {
  /// The `description` of a private clip.
  static const String description = 'private=1';

  /// Whether a clip whose `description` tag is [description] is private.
  static bool isPrivate(String? description) =>
      description != null &&
      description.split(';').contains(ClipPrivacyTag.description);
}
