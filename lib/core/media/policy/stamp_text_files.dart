/// What goes into the text files drawtext reads (`textfile=`).
abstract final class StampTextFiles {
  /// `date.txt`: the stamp text exactly. No trailing newline: drawtext would
  /// draw it as an empty second line and lift the bottom-anchored written
  /// date.
  static String date(String stampText) => stampText;

  /// `location.txt`: the place followed by a CR, or nothing when there is no
  /// place (the drawtext then draws nothing).
  ///
  /// The CR may lift the bottom-anchored place by a line. Kept so every
  /// clip of a movie draws the place the same way.
  static String location(String? place) =>
      place == null || place.isEmpty ? '' : '$place\r';
}
