import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';
import 'package:one_second_diary/features/settings/data/setting.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/domain/reminder_time.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/support.dart';
import '../../../support/track_1c/refusing_shared_preferences.dart';

Future<SettingsRepository> _settingsWith(Map<String, Object> values) async {
  final PrefsStore prefs = await openLegacyPrefs(values);
  return SettingsRepository(prefs: prefs);
}

/// Every plain on/off setting, by the key it is stored under.
Map<String, Setting<bool>> _toggles(SettingsRepository settings) =>
    <String, Setting<bool>>{
      'activatedNotification': settings.remindersEnabled,
      'persistentNotification': settings.persistentReminder,
      'timer': settings.countdownBeforeRecording,
      'recordWithFrontCamera': settings.recordWithFrontCamera,
      'forceNativeCamera': settings.forceNativeCamera,
      'enableGeotagging': settings.enableGeotagging,
      'useExperimentalPicker': settings.useExperimentalPicker,
      'useFilterInExperimentalPicker': settings.useFilterInExperimentalPicker,
      'useAlternativeCalendarColors': settings.useAlternativeCalendarColors,
      'verboseLogging': settings.verboseLogging,
      'calendarAutoPlay': settings.calendarAutoPlay,
      'calendarAutoSound': settings.calendarAutoSound,
    };

void main() {
  test('a refused write throws and announces nothing', () async {
    final (PrefsStore prefs, _) = await openRefusingPrefs(
      legacyPrefs(),
      refused: <String>{'timer'},
    );
    final SettingsRepository settings = SettingsRepository(prefs: prefs);
    final List<bool> announced = <bool>[];
    settings.countdownBeforeRecording.changes.listen(announced.add);

    await expectLater(
      settings.countdownBeforeRecording.set(true),
      throwsA(isA<StorageException>()),
    );
    await pumpEventQueue();

    expect(announced, isEmpty);
    expect(settings.countdownBeforeRecording.value, isFalse);
  });

  test('reading never writes: only a set stores a setting', () async {
    // calendarAutoPlay/Sound are the user's last explicit choice, and lang
    // is stored only when the user picks.
    final PrefsStore prefs = await openLegacyPrefs(
      legacyPrefs(extra: <String, Object>{'lang': 'it'}),
    );
    final SettingsRepository settings = SettingsRepository(prefs: prefs);
    final SharedPreferences legacy = await SharedPreferences.getInstance();
    final Map<String, Object?> before = <String, Object?>{
      for (final String key in legacy.getKeys()) key: legacy.get(key),
    };

    final List<Object?> read = <Object?>[
      ..._toggles(settings).values.map((Setting<bool> s) => s.value),
      settings.darkMode.value,
      settings.pickedLanguage.value,
      settings.appLanguage(deviceLanguageCode: 'pt'),
      settings.reminderTime.value,
      settings.recordingSeconds.value,
      settings.photoDurationMs.value,
      settings.stampStyle.value,
      settings.userName.value,
    ];

    expect(read, isNotEmpty);
    expect(<String, Object?>{
      for (final String key in legacy.getKeys()) key: legacy.get(key),
    }, before);
  });

  group('toggles', () {
    test(
      'read v1.7\'s defaults when nothing is stored (B §9 item 9)',
      () async {
        final SettingsRepository settings = await _settingsWith(legacyPrefs());

        expect(
          _toggles(
            settings,
          ).map((String key, Setting<bool> s) => MapEntry(key, s.value)),
          <String, bool>{
            'activatedNotification': false,
            'persistentNotification': false,
            'timer': false,
            'recordWithFrontCamera': false,
            'forceNativeCamera': false,
            'enableGeotagging': false,
            // A lost `false` here would flip the rule that never deletes the
            // user's original after an import.
            'useExperimentalPicker': true,
            'useFilterInExperimentalPicker': false,
            'useAlternativeCalendarColors': false,
            'verboseLogging': false,
            'calendarAutoPlay': true,
            'calendarAutoSound': true,
          },
        );
      },
    );

    test('read what v1.7 stored, each from its own key', () async {
      // Every toggle stored as the opposite of its default.
      final Map<String, bool> stored = <String, bool>{
        for (final MapEntry<String, Setting<bool>> toggle in _toggles(
          await _settingsWith(legacyPrefs()),
        ).entries)
          toggle.key: !toggle.value.value,
      };
      final SettingsRepository settings = await _settingsWith(
        legacyPrefs(extra: stored),
      );

      expect(
        _toggles(
          settings,
        ).map((String key, Setting<bool> s) => MapEntry(key, s.value)),
        stored,
      );
    });

    test('each is stored under its own legacy key, on and off, and '
        'announced', () async {
      for (final bool value in <bool>[true, false]) {
        final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
        final SettingsRepository settings = SettingsRepository(prefs: prefs);
        final List<bool> announced = <bool>[];
        settings.verboseLogging.changes.listen(announced.add);

        for (final Setting<bool> toggle in _toggles(settings).values) {
          await toggle.set(value);
        }
        await pumpEventQueue();

        final SharedPreferences legacy = await SharedPreferences.getInstance();
        for (final String key in _toggles(settings).keys) {
          expect(legacy.getBool(key), value, reason: key);
        }
        expect(announced, <bool>[value]);
      }
    });
  });

  // Clips go up to 60 s, so the clamp is 2..60.
  test('reads the stored seconds, clamped to 2..60 (D29), and stores seconds '
      'within 2..60, like the slider', () async {
    for (final (int? stored, int read) in <(int?, int)>[
      (null, 2),
      (5, 5),
      (1, 2),
      (0, 2),
      (10, 10),
      (61, 60),
    ]) {
      final SettingsRepository settings = await _settingsWith(
        legacyPrefs(extra: <String, Object>{'recordingSeconds': ?stored}),
      );
      expect(settings.recordingSeconds.value, read, reason: '$stored');
    }

    final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
    final SettingsRepository settings = SettingsRepository(prefs: prefs);
    final List<int> announced = <int>[];
    settings.recordingSeconds.changes.listen(announced.add);

    await settings.recordingSeconds.set(7);
    await settings.recordingSeconds.set(1);
    await settings.recordingSeconds.set(61);
    await pumpEventQueue();

    expect(announced, <int>[7, 2, 60]);
    expect(prefs.read(PrefKeys.recordingSeconds), 60);
  });

  group('photo duration', () {
    test('reads and stores a chip value; anything else reads 1 s, as in '
        'v1.7, and is never stored', () async {
      for (final (int? stored, int read) in <(int?, int)>[
        for (final int ms in <int>[1000, 1500, 2000, 3000, 5000, 10000])
          (ms, ms),
        (null, 1000),
        // 4 s is not a chip.
        (4000, 1000),
        (0, 1000),
      ]) {
        final SettingsRepository settings = await _settingsWith(
          legacyPrefs(extra: <String, Object>{'photoDurationMs': ?stored}),
        );
        expect(settings.photoDurationMs.value, read, reason: '$stored');
      }

      final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
      final SettingsRepository settings = SettingsRepository(prefs: prefs);
      await settings.photoDurationMs.set(1500);

      expect(prefs.read(PrefKeys.photoDurationMs), 1500);
      await expectLater(
        settings.photoDurationMs.set(4000),
        throwsArgumentError,
      );
      expect(prefs.read(PrefKeys.photoDurationMs), 1500);
    });
  });

  group('reminder time', () {
    test('reads the stored hour and minute; 20:00 when absent; a part '
        'outside the clock reads as its default; only a real time is '
        'stored', () async {
      for (final (Map<String, Object> stored, ReminderTime read)
          in <(Map<String, Object>, ReminderTime)>[
            (<String, Object>{}, (hour: 20, minute: 0)),
            (
              <String, Object>{
                'scheduledTimeHour': 7,
                'scheduledTimeMinute': 30,
              },
              (hour: 7, minute: 30),
            ),
            // Only a corrupt store holds these; the scheduler would roll
            // them over into another day.
            (
              <String, Object>{
                'scheduledTimeHour': 24,
                'scheduledTimeMinute': 75,
              },
              (hour: 20, minute: 0),
            ),
          ]) {
        final SettingsRepository settings = await _settingsWith(
          legacyPrefs(extra: stored),
        );
        expect(settings.reminderTime.value, read, reason: '$stored');
      }

      final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
      final SettingsRepository settings = SettingsRepository(prefs: prefs);
      final List<ReminderTime> announced = <ReminderTime>[];
      settings.reminderTime.changes.listen(announced.add);

      await settings.reminderTime.set((hour: 21, minute: 15));
      await pumpEventQueue();

      expect(announced, <ReminderTime>[(hour: 21, minute: 15)]);
      expect(prefs.read(PrefKeys.scheduledTimeHour), 21);
      expect(prefs.read(PrefKeys.scheduledTimeMinute), 15);
      await expectLater(
        settings.reminderTime.set((hour: 24, minute: 0)),
        throwsArgumentError,
      );
      await expectLater(
        settings.reminderTime.set((hour: 8, minute: 60)),
        throwsArgumentError,
      );
      expect(settings.reminderTime.value, (hour: 21, minute: 15));
    });
  });

  group('date stamp', () {
    test('reads the colour, format and outline v1.7 stored, or v1.7\'s '
        'default: a white numeric date with an outline', () async {
      expect(
        (await _settingsWith(
          legacyPrefs(
            extra: <String, Object>{
              'dateColor': '255,99,102,128',
              'dateFormatId': 1,
              'dateOutline': false,
            },
          ),
        )).stampStyle.value,
        const StampStyle(
          format: StampFormat.written,
          rgb: 0xFF6366,
          outline: false,
        ),
      );
      expect(
        (await _settingsWith(legacyPrefs())).stampStyle.value,
        const StampStyle(
          format: StampFormat.numeric,
          rgb: 0xFFFFFF,
          outline: true,
        ),
      );
    });

    test('a change writes only the part that changed, as v1.7 did', () async {
      final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
      final SettingsRepository settings = SettingsRepository(prefs: prefs);
      final List<StampStyle> announced = <StampStyle>[];
      settings.stampStyle.changes.listen(announced.add);
      const StampStyle written = StampStyle(
        format: StampFormat.written,
        rgb: 0xFFFFFF,
        outline: true,
      );
      const StampStyle red = StampStyle(
        format: StampFormat.written,
        rgb: 0xFF0000,
        outline: true,
      );

      await settings.stampStyle.set(written);

      expect(prefs.read(PrefKeys.dateFormatId), 1);
      expect(prefs.contains(PrefKeys.dateColor), isFalse);
      expect(prefs.contains(PrefKeys.dateOutline), isFalse);

      await settings.stampStyle.set(red);
      await pumpEventQueue();

      expect(prefs.read(PrefKeys.dateColor), '255,0,0,255');
      expect(prefs.contains(PrefKeys.dateOutline), isFalse);
      expect(announced, <StampStyle>[written, red]);
      expect(settings.stampStyle.value, red);
    });

    // The text size (owner request 2026-10-07) is stored under
    // `stampSize`, a token; an install without it (every one before this
    // build) reads medium, and only a change of size writes it.
    test('the text size reads from stampSize, medium when absent, and is '
        'written only when it changes', () async {
      expect(
        (await _settingsWith(legacyPrefs())).stampStyle.value.size,
        StampSize.medium,
      );
      expect(
        (await _settingsWith(
          legacyPrefs(extra: <String, Object>{'stampSize': 'large'}),
        )).stampStyle.value.size,
        StampSize.large,
      );
      expect(
        (await _settingsWith(
          legacyPrefs(extra: <String, Object>{'stampSize': 'huge'}),
        )).stampStyle.value.size,
        StampSize.medium,
      );

      final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
      final SettingsRepository settings = SettingsRepository(prefs: prefs);
      const StampStyle small = StampStyle(
        format: StampFormat.numeric,
        rgb: 0xFFFFFF,
        outline: true,
        size: StampSize.small,
      );

      await settings.stampStyle.set(small);

      expect(prefs.read(PrefKeys.stampSize), 'small');
      expect(prefs.contains(PrefKeys.dateColor), isFalse);
      expect(prefs.contains(PrefKeys.dateFormatId), isFalse);
      expect(prefs.contains(PrefKeys.dateOutline), isFalse);
      expect(settings.stampStyle.value, small);

      await settings.stampStyle.set(
        const StampStyle(
          format: StampFormat.written,
          rgb: 0xFFFFFF,
          outline: true,
          size: StampSize.small,
        ),
      );
      expect(prefs.read(PrefKeys.dateFormatId), 1);
      expect(prefs.read(PrefKeys.stampSize), 'small');

      await settings.stampStyle.set(
        const StampStyle(
          format: StampFormat.written,
          rgb: 0xFFFFFF,
          outline: true,
        ),
      );
      expect(prefs.read(PrefKeys.stampSize), 'medium');
      expect(settings.stampStyle.value.size, StampSize.medium);
    });
  });

  group('character', () {
    test(
      'the look reads as the default until one is stored, round-trips '
      'through its key, and the last Today visit is a day or absent',
      () async {
        final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
        final SettingsRepository settings = SettingsRepository(prefs: prefs);
        expect(settings.characterLook.value, CharacterLook.defaults);
        expect(settings.todayLastVisit.value, isNull);

        const CharacterLook look = CharacterLook(
          shape: CharacterShape.ghost,
          eyes: CharacterEyes.sleepy,
          mouth: CharacterMouth.cat,
          color: Color(0xFF4FB3A9),
          hidden: true,
        );
        await settings.characterLook.set(look);
        await settings.todayLastVisit.set(20_734);

        expect(settings.characterLook.value, look);
        expect(prefs.read(PrefKeys.characterLook), look.encode());
        expect(settings.todayLastVisit.value, 20_734);
      },
    );
  });

  group('user name (D2)', () {
    test('is empty until the user gives one, and stored trimmed; a blank '
        'name clears it', () async {
      final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
      final SettingsRepository settings = SettingsRepository(prefs: prefs);
      expect(settings.userName.value, '');

      await settings.userName.set('  Kyle ');

      expect(prefs.read(PrefKeys.userName), 'Kyle');

      await settings.userName.set('   ');

      expect(settings.userName.value, '');
      expect(prefs.read(PrefKeys.userName), '');
    });
  });

  group('language', () {
    test('a supported stored code is the user\'s pick; an unsupported one is '
        'ignored but left alone (flips G-4); a pick stores the bare code, '
        'and clearing it removes lang', () async {
      for (final (String? stored, AppLanguage? pick)
          in <(String?, AppLanguage?)>[
            ('cs', AppLanguage.cs),
            (null, null),
            ('it', null),
            ('fil', null),
          ]) {
        final SettingsRepository settings = await _settingsWith(
          legacyPrefs(extra: <String, Object>{'lang': ?stored}),
        );
        expect(settings.pickedLanguage.value, pick, reason: '$stored');
      }

      final PrefsStore prefs = await openLegacyPrefs(
        legacyPrefs(extra: <String, Object>{'lang': 'it'}),
      );
      final SettingsRepository settings = SettingsRepository(prefs: prefs);
      expect(settings.appLanguage(deviceLanguageCode: 'es'), AppLanguage.es);
      // The stored value is left as it is.
      expect(prefs.read(PrefKeys.lang), 'it');

      final List<AppLanguage?> announced = <AppLanguage?>[];
      settings.pickedLanguage.changes.listen(announced.add);
      await settings.pickedLanguage.set(AppLanguage.cs);
      await pumpEventQueue();

      expect(prefs.read(PrefKeys.lang), 'cs');
      expect(announced, <AppLanguage?>[AppLanguage.cs]);

      await settings.pickedLanguage.set(null);

      expect(prefs.contains(PrefKeys.lang), isFalse);
      expect(settings.appLanguage(deviceLanguageCode: 'fr'), AppLanguage.fr);
    });

    test('the device language is followed without being stored; an '
        'unsupported one runs in English (flips G-2 and G-3)', () async {
      final PrefsStore prefs = await openLegacyPrefs(freshInstallPrefs);
      final SettingsRepository settings = SettingsRepository(prefs: prefs);

      expect(settings.appLanguage(deviceLanguageCode: 'pt'), AppLanguage.pt);
      expect(settings.appLanguage(deviceLanguageCode: 'de'), AppLanguage.de);
      for (final String device in <String>['it', 'fil', 'su']) {
        expect(
          settings.appLanguage(deviceLanguageCode: device),
          AppLanguage.en,
          reason: device,
        );
      }
      expect(prefs.contains(PrefKeys.lang), isFalse);
    });
  });

  group('theme (D15)', () {
    test('a stored choice wins; a brand-new install follows the phone once, '
        'then keeps it; an existing install without the key keeps v1.7\'s '
        'dark theme and stores nothing; what v3 itself writes at launch '
        'does not make a new install look like an old one', () async {
      // (install, what is stored, the phone is dark, isDarkMode afterwards)
      final List<(String, Map<String, Object>, bool, bool?)> launches =
          <(String, Map<String, Object>, bool, bool?)>[
            (
              'stored light',
              legacyPrefs(extra: <String, Object>{'isDarkMode': false}),
              true,
              false,
            ),
            ('brand new', freshInstallPrefs, false, false),
            ('onboarded', legacyPrefs(), false, null),
            (
              'onboarded, nothing else kept',
              <String, Object>{'showIntro': false},
              false,
              null,
            ),
            // Older installs stored `lang` on their first launch, before the
            // intro.
            (
              'launched once, never onboarded',
              <String, Object>{'lang': 'de'},
              false,
              null,
            ),
            (
              'a profile left behind',
              <String, Object>{
                'profiles': <String>['Default', 'Work'],
              },
              false,
              null,
            ),
            // The log session, the path keys, the SDK level, the migrations
            // and the downgrade counters may all be written before the
            // theme is settled.
            (
              "brand new, after v3's own launch writes",
              <String, Object>{
                'currentLogFile': '2026-09-29_10-00-00.txt',
                'internalDirectoryPath': '/data/internal',
                'appPath': '/storage/emulated/0/DCIM/OneSecondDiary/',
                'moviesPath': '/storage/emulated/0/DCIM/OneSecondDiary/Movies/',
                'sdkVersion': 34,
                'osdSchemaVersion': 1,
                'videoCount': 0,
                'dailyEntry': false,
                'today': '2026-09-29',
              },
              false,
              false,
            ),
          ];

      for (final (
            String install,
            Map<String, Object> stored,
            bool phoneIsDark,
            bool? storedAfter,
          )
          in launches) {
        final PrefsStore prefs = await openLegacyPrefs(stored);
        final SettingsRepository settings = SettingsRepository(prefs: prefs);
        final bool dark = storedAfter ?? true;

        expect(
          await settings.settleThemeOnLaunch(platformIsDark: phoneIsDark),
          dark,
          reason: install,
        );
        expect(settings.darkMode.value, dark, reason: install);
        expect(
          prefs.contains(PrefKeys.isDarkMode)
              ? prefs.read(PrefKeys.isDarkMode)
              : null,
          storedAfter,
          reason: install,
        );
        // The next launch, the phone has turned the other way: the theme
        // stays.
        expect(
          await settings.settleThemeOnLaunch(platformIsDark: !phoneIsDark),
          dark,
          reason: '$install, next launch',
        );
      }
    });
  });
}
