/// The quick cuts under the trimmer: a chip per length, each offered only when the source is at least that long.
/// The last one tapped is remembered (`SettingsRepository.lastQuickCut`) as the window an import opens on.
abstract final class QuickCuts {
  /// The lengths, in ms, in chip order.
  static const List<int> lengthsMs = <int>[
    1000,
    1500,
    2000,
    3000,
    5000,
    10000,
    15000,
    30000,
    60000,
  ];

  /// The quick cut an import opens on before any was tapped: 1.5 s.
  static const int defaultMs = 1500;

  /// How close a dragged length must come to a chip to snap to it.
  static const int snapMs = 50;

  /// The chip [lengthMs] snaps to, or null when none is within [snapMs].
  static int? snapOf(int lengthMs) {
    for (final int cut in lengthsMs) {
      if ((lengthMs - cut).abs() <= snapMs) return cut;
    }
    return null;
  }

  /// [lengthMs] when it is a quick cut, else [defaultMs]: how the
  /// remembered quick cut is read, so a stored value that is no chip
  /// (another version's) never opens a window of an odd length.
  static int accepted(int? lengthMs) =>
      lengthMs != null && lengthsMs.contains(lengthMs) ? lengthMs : defaultMs;
}
