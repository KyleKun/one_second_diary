import 'dart:async';
import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/theme/osd_media.dart';

/// The colour of each tag's chip.
///
/// Every tag has a colour from its name ([indexOf] hashes `TagName.fold`
/// over the swatches of `OsdMedia.stampSwatches`, white, black and grey
/// left out), so chips are told apart without any set-up. Settings › Tags
/// lets the user pick one instead; those choices are the `tagColors`
/// preference, a JSON object of fold key to swatch index (`{"trip": 9}`).
/// A record that doesn't decode reads as empty, with one warning.
///
/// [changes] fires after each [set], so chips on screen follow. Kept a
/// plain class (not final) so screen tests can fake it.
class TagColors {
  TagColors({required this._prefs, required this._logger});

  final PrefsStore _prefs;
  final AppLogger _logger;

  static const String _tag = 'TAGS';

  /// The swatches a tag may take: `OsdMedia.stampSwatches` without white
  /// (0), black (1) and grey (14), which would not read as a tag colour.
  static const List<int> swatchIndexes = <int>[
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
  ];

  final StreamController<void> _changes = StreamController<void>.broadcast();
  String? _reported;

  /// Fires after each [set].
  Stream<void> get changes => _changes.stream;

  /// The swatch index (into `OsdMedia.stampSwatches`) of [tag]: the one
  /// chosen in Settings, else one from its name.
  int indexOf(String tag) {
    final String key = TagName.fold(tag);
    return _chosen()[key] ?? automaticIndexOf(tag);
  }

  /// The colour of [tag]'s chip.
  Color colorOf(String tag) => OsdMedia.stampSwatches[indexOf(tag)];

  /// Whether [tag]'s colour was chosen in Settings (else automatic).
  bool isChosen(String tag) => _chosen().containsKey(TagName.fold(tag));

  /// The swatch index [tag] takes from its name alone: stable across
  /// launches and phones, since it comes from the folded name.
  static int automaticIndexOf(String tag) {
    final String key = TagName.fold(tag);
    int hash = 0;
    for (final int unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return swatchIndexes[hash % swatchIndexes.length];
  }

  /// Chooses swatch [index] for [tag], or, with null, goes back to the
  /// automatic colour. Throws a [RangeError] for an index not in
  /// [swatchIndexes].
  Future<void> set(String tag, int? index) async {
    if (index != null && !swatchIndexes.contains(index)) {
      throw RangeError.value(index, 'index', 'not a tag swatch');
    }
    final Map<String, int> chosen = _chosen();
    final String key = TagName.fold(tag);
    if (index == null) {
      chosen.remove(key);
    } else {
      chosen[key] = index;
    }
    await _prefs.write(PrefKeys.tagColors, jsonEncode(chosen));
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Moves [from]'s chosen colour to [to] (a rename), unless [to] already
  /// has one.
  Future<void> rename(String from, String to) async {
    final Map<String, int> chosen = _chosen();
    final int? index = chosen[TagName.fold(from)];
    if (index == null) return;
    await set(from, null);
    if (!isChosen(to)) await set(to, index);
  }

  Future<void> dispose() => _changes.close();

  Map<String, int> _chosen() {
    final String stored = _prefs.read(PrefKeys.tagColors);
    final Object? json;
    try {
      json = jsonDecode(stored);
    } on FormatException {
      _report(stored);
      return <String, int>{};
    }
    if (json is! Map<String, Object?>) {
      _report(stored);
      return <String, int>{};
    }
    final Map<String, int> chosen = <String, int>{};
    for (final MapEntry<String, Object?> entry in json.entries) {
      final Object? value = entry.value;
      if (value is int && swatchIndexes.contains(value)) {
        chosen[entry.key] = value;
      } else {
        _report(stored);
      }
    }
    return chosen;
  }

  void _report(String stored) {
    if (stored == _reported) return;
    _reported = stored;
    _logger.warning(_tag, 'Ignored an unreadable tagColors preference');
  }
}
