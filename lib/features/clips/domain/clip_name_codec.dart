import 'package:one_second_diary/core/time/local_day.dart';

/// The clip file-name rule. A clip's name is the only source of its date.
///
/// - The first clip of a day is `yyyy-MM-dd.mp4`.
/// - Extra clips of the same day are `yyyy-MM-dd-N.mp4` with N ≥ 2: never
///   `_N` (movie temp copies from older installs are
///   `yyyy-MM-dd_<digits>.mp4`) and never an extra dot.
/// - The date is the local calendar date the clip is filed under, never
///   localised.
///
/// [parse] matches the WHOLE basename, case-sensitively, and validates the
/// date by round trip. It therefore rejects `.MP4`, Android media-store
/// `.pending-*` / `.trashed-*` entries, `_<digits>` temps, dotted names such
/// as `2024-01-05.edited.mp4`, impossible dates such as `2024-02-30` and
/// non-canonical ordinals (`-1`, `-02`). The scan logs every skipped `.mp4`
/// name under `[CALENDAR]`, so a bug report shows them.
abstract final class ClipNameCodec {
  /// The file name of clip [ordinal] (1-based) of [day].
  static String format(LocalDay day, {int ordinal = 1}) {
    if (ordinal < 1) {
      throw ArgumentError.value(ordinal, 'ordinal', 'must be 1 or more');
    }
    return ordinal == 1
        ? '${day.fileStem}.mp4'
        : '${day.fileStem}-$ordinal.mp4';
  }

  /// The day and ordinal named by [fileName] (a basename, not a path), or
  /// null when it is not exactly a clip name.
  static ({LocalDay day, int ordinal})? parse(String fileName) {
    final RegExpMatch? match = _pattern.firstMatch(fileName);
    if (match == null) return null;
    final LocalDay? day = LocalDay.tryParseStem(match.group(1)!);
    final String? suffix = match.group(2);
    final int? ordinal = suffix == null ? 1 : int.tryParse(suffix);
    if (day == null || ordinal == null) return null;
    return (day: day, ordinal: ordinal);
  }

  /// Whether [fileName] (a basename) is a copy older installs left behind
  /// while making a movie, `yyyy-MM-dd_<1–6 digits>.mp4`. Never a clip; the
  /// orphan sweep deletes these from clip folders while no media job runs.
  static bool isLegacyMovieTemp(String fileName) =>
      _legacyMovieTemp.hasMatch(fileName);

  // The ordinal suffix is canonical: 2–9 or a multi-digit number without a
  // leading zero, so every clip has exactly one possible name.
  static final RegExp _pattern = RegExp(
    r'^(\d{4}-\d{2}-\d{2})(?:-([2-9]|[1-9]\d+))?\.mp4$',
  );

  static final RegExp _legacyMovieTemp = RegExp(
    r'^\d{4}-\d{2}-\d{2}_\d{1,6}\.mp4$',
  );
}
