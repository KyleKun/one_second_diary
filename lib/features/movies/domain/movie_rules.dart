/// The rules every movie follows, whichever screen asks.
abstract final class MovieRules {
  /// The fewest clips a movie joins (two clips of one day are enough).
  /// Below it "Create movie" and the flow's Continue are off.
  static const int minClips = 2;
}
