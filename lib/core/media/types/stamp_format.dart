/// Which date text is burned into a clip, and where.
enum StampFormat {
  /// Localised numeric date (`02/06/2024`), top right.
  numeric(0),

  /// Localised written date (`June 2, 2024`), bottom left.
  written(1);

  const StampFormat(this.id);

  /// The value stored in the `dateFormatId` preference.
  final int id;

  /// The format for a stored `dateFormatId`. Only exactly 1 is [written].
  static StampFormat fromId(int id) => id == written.id ? written : numeric;
}
