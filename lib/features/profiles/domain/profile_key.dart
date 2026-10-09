/// A profile's identity: its folder name under `Profiles/`, or `''` for the
/// Default profile, whose clips live at the root of the videos folder.
///
/// The key never changes (renaming changes only the display name). Default is
/// recognised by the empty key, never by its label: a user profile may be
/// called "Default".
extension type const ProfileKey(String value) {
  /// The key of entry [index] of the stored `profiles` list, whose text is
  /// [label]. Index 0 is always the Default profile, whatever its label;
  /// every other label is its own folder key.
  factory ProfileKey.fromLegacyIndex(int index, String label) =>
      index == 0 ? defaultProfile : ProfileKey(label);

  /// The built-in profile at index 0 of the stored `profiles` list.
  static const ProfileKey defaultProfile = ProfileKey('');

  bool get isDefault => value.isEmpty;

  /// The label in a clip's `album` tag and in logs: `Default` for the
  /// Default profile, otherwise the key; never the display name, which a
  /// rename changes.
  String get albumLabel => isDefault ? 'Default' : value;
}
