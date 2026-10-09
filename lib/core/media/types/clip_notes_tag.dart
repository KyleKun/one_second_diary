/// The app's notes about a clip, written into its `synopsis` metadata (the
/// MP4 `ldes` atom) as a `;`-separated list of `key=value` parts, like a
/// movie's description:
///
/// ```
/// synopsis=device=Android 14 (SDK 34), Google Pixel 8;app=2.0.0;recorded=2026-10-06T14:33:21.000+02:00;place=Home
/// ```
///
/// - `device`, `app`, `recorded`: the phone, the app version and the
///   moment, written only when the "Device info in videos" preference is
///   on ([format]). Nothing in the app reads them back: they are for the
///   user's own files (an `ffprobe`, a future Info sheet).
/// - `place`: the place the user typed or picked for a clip that has no
///   GPS fix ([withPlace]), which the `location` tag cannot carry without
///   pinning the clip at 0°,0° in galleries (the legacy `+0+0/` form). The
///   metadata cache reads it back (`clipMetaOfProbe`), so the Diary shows
///   it and search finds it. A place WITH a fix goes into `location` only.
/// - `muted`: `1` once the clip's sound was replaced with silence
///   ([withMuted], read by [isMuted]), so the Edit sheets say "Muted" and
///   never offer it again.
///
/// Written at save time; a remux keeps the tag as it is. The tag is
/// `synopsis` and not `encoder` because ffmpeg always overwrites `encoder`
/// with its own version. The parts never contain `;` ([_part] replaces
/// it).
abstract final class ClipNotesTag {
  static const String _separator = ';';

  /// The device parts. [device] is `DeviceInfoGateway.description()`,
  /// [appVersion] `AppInfoGateway.version()`, [recordedAt] the save moment
  /// in the phone's local time, written as ISO 8601 with its UTC offset.
  static String format({
    required String device,
    required String appVersion,
    required DateTime recordedAt,
  }) => <String>[
    'device=${_part(device)}',
    'app=${_part(appVersion)}',
    'recorded=${_iso(recordedAt)}',
  ].join(_separator);

  /// [notes] (the device parts, or null) plus `place=<place>`; just the
  /// place part when there are no notes. An empty [place] adds nothing.
  static String? withPlace(String? notes, String place) {
    final String cleaned = _part(place);
    if (cleaned.isEmpty) return notes;
    final String part = 'place=$cleaned';
    return notes == null || notes.isEmpty ? part : '$notes$_separator$part';
  }

  /// The `muted` part's key and value.
  static const String mutedKey = 'muted';
  static const String mutedValue = '1';

  /// [notes] (any parts, or null) plus `muted=1`; just that part when
  /// there are no notes; [notes] as they are when they already say so.
  static String withMuted(String? notes) {
    if (parse(notes)[mutedKey] == mutedValue) return notes!;
    const String part = '$mutedKey=$mutedValue';
    return notes == null || notes.isEmpty ? part : '$notes$_separator$part';
  }

  /// Whether [synopsis] says the clip was muted.
  static bool isMuted(String? synopsis) =>
      parse(synopsis)[mutedKey] == mutedValue;

  /// The parts of a `synopsis` value by key (`device`, `app`, `recorded`,
  /// `place`, `muted`); empty when [synopsis] is not one of ours. Never
  /// throws.
  static Map<String, String> parse(String? synopsis) {
    if (synopsis == null) return const <String, String>{};
    final Map<String, String> parts = <String, String>{};
    for (final String part in synopsis.split(_separator)) {
      final int at = part.indexOf('=');
      if (at <= 0) continue;
      parts[part.substring(0, at)] = part.substring(at + 1);
    }
    return parts;
  }

  static String _part(String value) => value.replaceAll(_separator, ',').trim();

  /// `2026-10-06T14:33:21.000+02:00`: local wall time with the offset, so
  /// the moment and the time zone it was recorded in are both kept.
  static String _iso(DateTime moment) {
    final DateTime local = moment.isUtc ? moment.toLocal() : moment;
    final Duration offset = local.timeZoneOffset;
    final String sign = offset.isNegative ? '-' : '+';
    final int minutes = offset.inMinutes.abs();
    final String hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final String mm = (minutes % 60).toString().padLeft(2, '0');
    final String stamp = local.toIso8601String();
    // toIso8601String has no offset for a local time (and may carry
    // microseconds): keep whole milliseconds.
    final String base = stamp.length > 23 ? stamp.substring(0, 23) : stamp;
    return '$base$sign$hh:$mm';
  }
}
