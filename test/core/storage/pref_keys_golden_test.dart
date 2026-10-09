import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/pref_key.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// GOLDEN: the keys older installs have stored.
///
/// A failure here means a refactor renamed a key, changed its storage type or
/// its reader default. Existing users would silently lose that setting. Do not
/// update this table to make a test pass; fix the key instead.
const List<List<Object?>> _legacyLive = <List<Object?>>[
  <Object?>['showIntro', PrefType.boolean, null],
  <Object?>[
    'profiles',
    PrefType.stringList,
    <String>['Default'],
  ],
  <Object?>['selectedProfileIndex', PrefType.integer, 0],
  <Object?>['videoCount', PrefType.integer, null],
  <Object?>['movieCount', PrefType.integer, null],
  <Object?>['dailyEntry', PrefType.boolean, false],
  <Object?>['today', PrefType.string, ''],
  <Object?>['lang', PrefType.string, ''],
  <Object?>['isDarkMode', PrefType.boolean, true],
  <Object?>['activatedNotification', PrefType.boolean, false],
  <Object?>['persistentNotification', PrefType.boolean, false],
  <Object?>['scheduledTimeHour', PrefType.integer, 20],
  <Object?>['scheduledTimeMinute', PrefType.integer, 0],
  <Object?>['timer', PrefType.boolean, false],
  <Object?>['recordingSeconds', PrefType.integer, 2],
  <Object?>['recordWithFrontCamera', PrefType.boolean, false],
  <Object?>['dateColor', PrefType.string, ''],
  <Object?>['dateFormatId', PrefType.integer, 0],
  <Object?>['dateOutline', PrefType.boolean, true],
  <Object?>['enableGeotagging', PrefType.boolean, false],
  <Object?>['photoDurationMs', PrefType.integer, 1000],
  <Object?>['forceNativeCamera', PrefType.boolean, false],
  <Object?>['strictClipLength', PrefType.boolean, false],
  <Object?>['useExperimentalPicker', PrefType.boolean, true],
  <Object?>['useFilterInExperimentalPicker', PrefType.boolean, false],
  <Object?>['useAlternativeCalendarColors', PrefType.boolean, false],
  <Object?>['verboseLogging', PrefType.boolean, false],
  <Object?>['calendarAutoPlay', PrefType.boolean, true],
  <Object?>['calendarAutoSound', PrefType.boolean, true],
  <Object?>['sdkVersion', PrefType.integer, null],
  <Object?>['currentLogFile', PrefType.string, ''],
];

const List<List<Object?>> _legacyWriteOnlyPaths = <List<Object?>>[
  <Object?>['internalDirectoryPath', PrefType.string, ''],
  <Object?>['appPath', PrefType.string, ''],
  <Object?>['moviesPath', PrefType.string, ''],
];

const List<List<Object?>> _v3 = <List<Object?>>[
  <Object?>['userName', PrefType.string, ''],
  <Object?>['profileMeta', PrefType.string, '{}'],
  <Object?>['legacyStampFont', PrefType.boolean, false],
  <Object?>['clipDeviceInfo', PrefType.boolean, true],
  <Object?>['tagColors', PrefType.string, '{}'],
  <Object?>['savedPlaces', PrefType.string, '[]'],
  <Object?>['dualCamera', PrefType.boolean, false],
  <Object?>['dualCameraSplit', PrefType.boolean, false],
  <Object?>['moviesLargeView', PrefType.boolean, false],
  <Object?>['diaryMemoriesView', PrefType.boolean, false],
  <Object?>['osdSchemaVersion', PrefType.integer, 0],
  <Object?>['lastQuickCutMs', PrefType.integer, 1500],
  <Object?>['deviceMediaProfile', PrefType.string, ''],
  <Object?>['keepOriginals', PrefType.boolean, false],
  <Object?>['framingBlurPortrait', PrefType.boolean, true],
  <Object?>['framingBlurLandscape', PrefType.boolean, false],
  <Object?>['importKeepWhole', PrefType.boolean, false],
  <Object?>['importDateStamp', PrefType.boolean, true],
  <Object?>['whatsNewQuality', PrefType.boolean, false],
  // The burned text size: a StampSize token, '' = medium (the 40 px every
  // clip was burned with).
  <Object?>['stampSize', PrefType.string, ''],
  <Object?>['characterLook', PrefType.string, ''],
  <Object?>['todayLastVisit', PrefType.integer, null],
  <Object?>['placeCoordinates', PrefType.string, '{}'],
];

const List<String> _deadNeverReuse = <String>[
  'showChangelogV15',
  'showChangelogV152',
  'isGeotaggingEnabled',
  'dateFormat',
];

List<List<Object?>> _rows(List<PrefKey<Object?>> keys) => <List<Object?>>[
  for (final PrefKey<Object?> key in keys)
    <Object?>[key.name, key.type, key.defaultValue],
];

void main() {
  test('the 31 fixed live legacy keys keep name, type and reader default', () {
    expect(_rows(PrefKeys.legacyLive), _legacyLive);
    expect(PrefKeys.legacyLive, hasLength(31));
  });

  test('orientation_<key> is the 32nd live key, one per profile', () {
    final PrefKey<String> defaultKey = PrefKeys.orientation(
      ProfileKey.defaultProfile,
    );
    final PrefKey<String> work = PrefKeys.orientation(const ProfileKey('Work'));

    expect(
      <Object?>[defaultKey.name, defaultKey.type, defaultKey.defaultValue],
      <Object?>['orientation_', PrefType.string, ''],
    );
    expect(work.name, 'orientation_Work');
  });

  // The write-once format of a profile, one key per profile like orientation_<key>;
  // absent means the legacy format.
  test('clipFormat_<key> is a key per profile, a string, absent = legacy', () {
    final PrefKey<String> defaultKey = PrefKeys.clipFormat(
      ProfileKey.defaultProfile,
    );
    final PrefKey<String> work = PrefKeys.clipFormat(const ProfileKey('Work'));

    expect(
      <Object?>[defaultKey.name, defaultKey.type, defaultKey.defaultValue],
      <Object?>['clipFormat_', PrefType.string, ''],
    );
    expect(work.name, 'clipFormat_Work');
  });

  // The key stays listed for v1.7 and is never reused: this pins that it is still in the
  // live table above.
  test('strictClipLength stays listed, unread, with its default', () {
    expect(PrefKeys.legacyLive, contains(PrefKeys.strictClipLength));
    expect(PrefKeys.strictClipLength.defaultValue, isFalse);
  });

  test('the write-only path keys and the v3 keys keep name, type and '
      'default', () {
    expect(_rows(PrefKeys.legacyWriteOnlyPaths), _legacyWriteOnlyPaths);
    expect(_rows(PrefKeys.v3), _v3);
  });

  test('all is every fixed key exactly once, and no dead historic name is '
      'ever reused', () {
    final List<String> names = <String>[
      for (final PrefKey<Object?> key in PrefKeys.all) key.name,
    ];
    expect(names.toSet(), hasLength(names.length));
    expect(names, <String>[
      for (final List<Object?> row in <List<Object?>>[
        ..._legacyLive,
        ..._legacyWriteOnlyPaths,
        ..._v3,
      ])
        row.first! as String,
    ]);

    expect(PrefKeys.deadNeverReuse, _deadNeverReuse);
    expect(names.toSet().intersection(_deadNeverReuse.toSet()), isEmpty);
    expect(names.any((String n) => n.startsWith('orientation_')), isFalse);
    expect(names.any((String n) => n.startsWith('clipFormat_')), isFalse);
  });
}
