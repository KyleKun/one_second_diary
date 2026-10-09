import 'package:one_second_diary/core/storage/storage_budget.dart';

/// The free-space check before a movie, on `StorageBudget`: the normalised
/// copies the engine makes first and the movie twice (joined in scratch, then
/// copied into the gallery on Android), with the 200 MB floor kept.
abstract final class MovieSpace {
  /// Without the clips' facts, the normalised copies are taken as a tenth
  /// of the clips (the 2.1× of earlier versions).
  static const double assumedNormalisedShare = 0.1;

  /// The free bytes a movie of [clipBytes] of clips needs, with
  /// [normalisedBytes] of copies made first (a tenth of the clips when not
  /// known).
  static int neededFor(int clipBytes, {int? normalisedBytes}) =>
      StorageBudget.movieBytes(
        clipBytes: clipBytes,
        normalisedBytes:
            normalisedBytes ?? (clipBytes * assumedNormalisedShare).ceil(),
      );

  /// How many more bytes [needed] takes than are [free] (the floor kept); null
  /// when enough is free, or when the free space is not known (the check never
  /// stops a movie on a guess).
  static int? shortfall({required int needed, required int? free}) =>
      switch (StorageBudget.check(needed: needed, free: free)) {
        StorageOk() => null,
        StorageShort(:final int shortfallBytes) => shortfallBytes,
      };
}
