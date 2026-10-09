import 'dart:convert';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// One profile's entry in the `profileMeta` record: its display name when it
/// differs from the folder key, and its photo relative to `AppPaths.internal`.
typedef ProfileMeta = ({String? displayName, String? avatarRelPath});

/// The `profileMeta` record: a JSON object keyed by folder key (`''` is
/// Default), e.g. `{"Travel": {"displayName": "Viagem ✈"}}`.
///
/// A record that doesn't decode reads as empty, with a warning, instead of
/// breaking the profile list.
final class ProfileMetaStore {
  ProfileMetaStore({required this._prefs, required this._logger});

  final PrefsStore _prefs;
  final AppLogger _logger;

  /// The stored value last reported as corrupt, so reading it again (which
  /// happens on every profile read) doesn't repeat the warning.
  String? _reported;

  /// Every entry, by folder key.
  Map<ProfileKey, ProfileMeta> read() {
    final String stored = _prefs.read(PrefKeys.profileMeta);
    final Map<ProfileKey, ProfileMeta> entries = <ProfileKey, ProfileMeta>{};
    final Object? json;
    try {
      json = jsonDecode(stored);
    } on FormatException {
      _report(stored);
      return entries;
    }
    if (json is! Map<String, Object?>) {
      _report(stored);
      return entries;
    }
    for (final MapEntry<String, Object?>(:String key, :Object? value)
        in json.entries) {
      if (value is! Map<String, Object?>) {
        _report(stored);
        continue;
      }
      entries[ProfileKey(key)] = (
        displayName: _text(value['displayName'], stored),
        avatarRelPath: _text(value['avatarRelPath'], stored),
      );
    }
    return entries;
  }

  /// Stores [meta] as [key]'s entry; an entry with neither a name nor a
  /// photo is removed. Parts of the record that don't decode are dropped.
  Future<void> put({required ProfileKey key, required ProfileMeta meta}) async {
    final Map<ProfileKey, ProfileMeta> entries = read();
    if (meta.displayName == null && meta.avatarRelPath == null) {
      entries.remove(key);
    } else {
      entries[key] = meta;
    }
    await _prefs.write(
      PrefKeys.profileMeta,
      jsonEncode(<String, Object>{
        for (final MapEntry<ProfileKey, ProfileMeta>(:ProfileKey key, :value)
            in entries.entries)
          key.value: <String, String>{
            'displayName': ?value.displayName,
            'avatarRelPath': ?value.avatarRelPath,
          },
      }),
    );
  }

  String? _text(Object? value, String stored) {
    if (value == null || value is String && value.trim().isNotEmpty) {
      return value as String?;
    }
    _report(stored);
    return null;
  }

  void _report(String stored) {
    if (stored == _reported) return;
    _reported = stored;
    _logger.warning(
      'PROFILES',
      'Ignoring an unreadable part of profileMeta: $stored',
    );
  }
}
