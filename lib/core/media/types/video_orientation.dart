/// The canvas a profile's clips and movies target: 1920×1080 (landscape) or
/// 1080×1920 (portrait).
///
/// Chosen once when a profile is created and never changed, because movies
/// are stream-copy joins of clips that must share one canvas. Stored by
/// [name] in the `orientation_<profile>` preference.
enum VideoOrientation {
  landscape,
  portrait;

  /// Parses a stored orientation. Missing or unrecognised values are
  /// landscape: a profile from an older install has no stored value.
  static VideoOrientation parse(String? stored) =>
      values.asNameMap()[stored] ?? VideoOrientation.landscape;
}
